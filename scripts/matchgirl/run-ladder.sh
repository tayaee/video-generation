#!/usr/bin/env bash
# scripts/matchgirl/run-ladder.sh: s10 → s04 → s08 → s20 → s50 순차 실행 + 프로파일별 assemble.
# 무인 실행용. 재시도(프로파일당 3회)·서버 복구·s20 RES 폴백 내장.
# 실패 프로파일은 FAILED로 기록 후 다음으로 계속. 절대 중간에 멈추지 않음.
#   ./run-ladder.sh                      # 전체 (flock 단일 실행)
#   ./run-ladder.sh s20,s50              # 일부만 (콤마 구분)
# 로그는 호출자가 리다이렉트 (/tmp/ladder-run.log 권장).
set -uo pipefail

REPO="$HOME/git/video-generation"
[ -d "$REPO/results" ] || REPO="$(cd "$(dirname "$0")/../.." && pwd)"
H3_URL="http://127.0.0.1:8000"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
SPARK2="spark2-p1-r0"
ASSEMBLE="$REPO/scripts/common/assemble.sh"
H3_SERVE="$REPO/setup/infra/dgx-spark-1/model/minimax-h3/3-serve-fl2va.sh"
COMFY_DIR_NEW="$REPO/setup/infra/dgx-spark-2/service/comfyui"

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*"; }

h3_ok() { curl -sf -m 5 -o /dev/null "$H3_URL/health" 2>/dev/null; }
comfy_ok() { curl -sf -m 10 -o /dev/null "$COMFY_URL/system_stats" 2>/dev/null; }

ensure_h3() { # 2회 시도
  h3_ok && { log "h3 OK"; return 0; }
  for i in 1 2; do
    log "h3 복구 시도 $i: 3-serve-fl2va.sh"
    bash "$H3_SERVE" >>"/tmp/ladder-h3-serve.log" 2>&1 || true
    h3_ok && { log "h3 복구됨"; return 0; }
  done
  log "h3 복구 실패"; return 1
}

ensure_comfy() { # 프록시→직통→spark2 재기동 순
  comfy_ok && { log "comfy OK"; return 0; }
  log "comfy 프록시 불통, 직통 확인"
  COMFY_URL="http://192.168.102.2:8188" comfy_ok 2>/dev/null && {
    log "comfy 직통 OK (프록시 문제, 직통으로 계속)"; COMFY_URL="http://192.168.102.2:8188"; return 0; }
  for i in 1 2; do
    log "comfy 재기동 시도 $i (spark2)"
    timeout 900 ssh -o BatchMode=yes -o ConnectTimeout=10 "$SPARK2" \
      'D=~/git/video-generation/setup/infra/dgx-spark-2/service/comfyui; [ -d "$D" ] || D=~/git/video-generation/video/infra/dgx-spark-2/service/comfyui; cd "$D" && ./5-up.sh' \
      >>"/tmp/ladder-comfy-up.log" 2>&1 || true
    sleep 30
    comfy_ok && { log "comfy 복구됨"; return 0; }
  done
  log "comfy 복구 실패"; return 1
}

count_mp4() { # $1=shotsdir → 개수 출력
  ls "$1"/*.mp4 2>/dev/null | wc -l
}

run_profile() { # name script server [env...] — 성공 시 0
  local name="$1" script="$2" server="$3"; shift 3
  local dir shots Tries=3
  dir="$(dirname "$script")"
  shots="$dir/shots"
  log "===== PROFILE $name 시작 ($script) ====="
  local attempt
  for attempt in 1 2 3; do
    if [ "$server" = "h3" ]; then
      ensure_h3 || { log "$name: h3 없음, attempt $attempt 스킵"; sleep 60; continue; }
    else
      ensure_comfy || { log "$name: comfy 없음, attempt $attempt 스킵"; sleep 60; continue; }
    fi
    # s20 폴백: 3회차는 저해상도로
    if [ "$name" = "s20-480p-comfy-base" ] && [ "$attempt" -eq 3 ]; then
      log "$name: RES 폴백 864x480 -> 608x352"
      set -- RES=608x352 "$@"
    fi
    log "$name: attempt $attempt 실행"
    # shellcheck disable=SC2068
    if env "$@" bash "$script"; then
      if [ "$(count_mp4 "$shots")" -eq 36 ]; then
        log "$name: 36샷 완성"
        return 0
      fi
      log "$name: 종료됐으나 $(count_mp4 "$shots")/36개 (재시도)"
    else
      log "$name: attempt $attempt 실패 (exit $?)"
    fi
    sleep 30
  done
  log "$name: FAILED (3회 초과)"
  return 1
}

assemble_profile() { # profdir tag — OUT 명시, sidecar 자동
  local profdir="$1" tag="$2"
  local shots="$profdir/shots"
  local out="$profdir/matchgirl_${tag}.mp4"
  log "===== ASSEMBLE $tag ====="
  if bash "$ASSEMBLE" "$shots" "$out"; then
    log "ASSEMBLE $tag OK: $out"
    return 0
  else
    log "ASSEMBLE $tag WARN/FAIL (로그 확인)"
    return 1
  fi
}

main() {
  exec 9>/tmp/ladder.lock
  flock -n 9 || { log "이미 실행 중 (ladder lock). 종료"; return 1; }
  local only="${1:-all}"
  declare -A WANT=()
  if [ "$only" != "all" ]; then
    IFS=',' read -ra SEL <<<"$only"
    for s in "${SEL[@]}"; do WANT["$s"]=1; done
  fi
  want() { [ "$only" = "all" ] || [ -n "${WANT[$1]:-}" ]; }
  local pass=0 fail=0 failed_list=""
  local P="$REPO/scripts/matchgirl/profiles"
  # 순서 고정: s10 → s04 → s08 → s20 → s50
  local seq="s10-576p-vllm-t2va:h3 s04-352p-comfy-turbo:comfy s08-352p-comfy-turbo:comfy s20-480p-comfy-base:comfy s50-576p-vllm-t2va:h3"
  local entry name server script tag rc
  for entry in $seq; do
    name="${entry%%:*}"; server="${entry##*:}"
    script="$P/$name/generate.sh"
    tag="${name%%-*}"  # s10, s04, ...
    [ -x "$script" ] || { log "$name: 스크립트 없음, 스킵"; continue; }
    want "$name" || { log "$name: 선택 제외, 스킵"; continue; }
    rc=0
    run_profile "$name" "$script" "$server" || rc=1
    if [ "$(count_mp4 "$P/$name/shots")" -gt 0 ]; then
      assemble_profile "$P/$name" "$tag" || rc=1
    else
      log "$name: 산출물 없음, assemble 생략"; rc=1
    fi
    if [ "$rc" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); failed_list="$failed_list $name"; fi
  done
  log "===== LADDER DONE: pass=$pass fail=$fail [$failed_list ] ====="
  [ "$fail" -eq 0 ]
}

main "$@"
