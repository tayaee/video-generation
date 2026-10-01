#!/usr/bin/env bash
# mirror-results.sh: <repo>/results 하위 산출물 → NAS Secondary 미러링 (삭제 없음).
#   직접 실행: ./mirror-results.sh              # results/ 전체 1회 동기화
#   공통 함수: . ./mirror-results.sh && mirror_results
#              (generate.sh·assemble.sh가 매 샷/완성 시 호출)
# - results/ 아래 생기는 것은 mp4·json·csv·숨김파일까지 전부 복사.
# - 타겟 삭제(--delete)는 하지 않음. rsync增分이라 이미 있는 파일은 스킵.
# - /rosenas/data/AIML 없으면(미마운트 등) 조용히 무시하고 0 반환.
# - 절대 호출자를 깨지 않음: 실패해도 0 반환. MIRROR_VERBOSE=1일 때만 출력.
# - DEST 변경: NAS_DEST=/path ./mirror-results.sh
set -uo pipefail

mirror_results() {
  local root src dest
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  src="$root/results"
  dest="${NAS_DEST:-/rosenas/data/AIML/video-generation/results}"
  guard="${MIRROR_GUARD:-/rosenas/data/AIML}"
  [ -d "$guard" ] || return 0
  [ -d "$src" ] || return 0
  mkdir -p "$dest" 2>/dev/null || return 0
  [ -w "$dest" ] || return 0
  if command -v rsync >/dev/null 2>&1; then
    if [ "${MIRROR_VERBOSE:-0}" = "1" ]; then
      rsync -a "$src/" "$dest/" || return 0
    else
      rsync -a --quiet "$src/" "$dest/" >/dev/null 2>&1 || return 0
    fi
  elif [ "${MIRROR_VERBOSE:-0}" = "1" ]; then
    (cd "$src" && cp -av . "$dest/") || return 0
  else
    (cd "$src" && cp -a . "$dest/") >/dev/null 2>&1 || return 0
  fi
  return 0
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  mirror_results "$@"
fi
