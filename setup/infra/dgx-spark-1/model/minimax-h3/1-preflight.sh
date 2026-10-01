#!/usr/bin/env bash
# 1-preflight: MiniMax-H3 @ DGX Spark(GB10, 1x) 사전 점검. 실행 순서 1/9.
# 치명적 결함(docker/GPU 없음)만 exit 1, 나머지는 WARN으로 보고.
set -euo pipefail

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS: $*"; }
warn() { WARN=$((WARN+1)); echo "WARN: $*"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $*"; }

echo "== arch =="
ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] && ok "arch=$ARCH" || warn "arch=$ARCH (GB10 기대값: aarch64)"

echo "== memory (unified pool) =="
if [ -r /proc/meminfo ]; then
  MEM_GIB=$(awk '/MemTotal/{printf "%.1f", $2/1024/1024}' /proc/meminfo)
  echo "MemTotal: ${MEM_GIB} GiB (기대 ~121 GiB usable)"
  awk '/MemTotal/{if ($2/1024/1024 < 100) exit 1}' /proc/meminfo && ok "unified mem ${MEM_GIB} GiB" \
    || warn "usable mem < 100 GiB, Ref2VA 불가 가능"
else
  warn "/proc/meminfo 없음"
fi

echo "== gpu / driver =="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || warn "nvidia-smi 쿼리 실패"
  ok "nvidia-smi 존재"
else
  fail "nvidia-smi 없음"
fi

echo "== docker =="
if docker info >/dev/null 2>&1; then
  ok "docker daemon OK ($(docker --version))"
else
  fail "docker daemon 접근 불가"
fi

echo "== hf cli =="
if command -v hf >/dev/null 2>&1 || command -v huggingface-cli >/dev/null 2>&1; then
  ok "huggingface cli 존재"
else
  warn "hf/huggingface-cli 없음 (2-download.sh 실행 전 설치 필요: pip install -U huggingface_hub)"
fi

echo "== curl / ffprobe =="
command -v curl >/dev/null 2>&1 && ok "curl OK" || fail "curl 없음"
command -v ffprobe >/dev/null 2>&1 && ok "ffprobe OK" || warn "ffprobe 없음 (mp4 검증 스킵됨)"

echo "== disk (파티션당 135 GiB 필요, FL2VA/Ref2VA 별도) =="
H3_ROOT="${H3_ROOT:-$HOME/models/MiniMax-H3}"
mkdir -p "$H3_ROOT"
AVAIL_GB=$(df -BG "$(readlink -f "$H3_ROOT")" | awk 'NR==2{gsub("G","",$4); print $4}')
echo "H3_ROOT=$H3_ROOT avail=${AVAIL_GB}G"
[ "${AVAIL_GB:-0}" -ge 140 ] && ok "디스크 ${AVAIL_GB}G (FL2VA 1파티션 가능)" \
  || warn "디스크 ${AVAIL_GB}G < 140G, 1파티션도 부족. 둘 다 받으려면 280G+"
[ "${AVAIL_GB:-0}" -ge 280 ] && ok "디스크 ${AVAIL_GB}G (양 파티션 가능)"

echo "== ports =="
for P in 8000 8188; do
  if (command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$P ") \
    || curl -s -m 2 "http://127.0.0.1:$P/health" >/dev/null 2>&1 \
    || curl -s -m 2 "http://127.0.0.1:$P/system_stats" >/dev/null 2>&1; then
    warn "port $P 사용중 (기존 서버 있으면 8/9-stop으로 정리)"
  else
    ok "port $P 비어있음"
  fi
done

echo
echo "===== preflight: PASS=$PASS WARN=$WARN FAIL=$FAIL ====="
echo "다음: ./2-download.sh [FL2VA|Ref2VA|all]  (기본 FL2VA)"
[ "$FAIL" -gt 0 ] && exit 1 || true
