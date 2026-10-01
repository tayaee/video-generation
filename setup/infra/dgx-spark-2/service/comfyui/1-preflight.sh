#!/usr/bin/env bash
# 1-preflight: ComfyUI+H3 @ DGX Spark(GB10, 1x) 사전 점검. 실행 순서 1/9.
set -euo pipefail

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS: $*"; }
warn() { WARN=$((WARN+1)); echo "WARN: $*"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $*"; }

DATA_ROOT="${DATA_ROOT:-$HOME/data/minimax-h3-comfyui}"

[ "$(uname -m)" = "aarch64" ] && ok "arch=aarch64" || warn "arch=$(uname -m)"
awk '/MemTotal/{printf "MemTotal: %.1f GiB\n", $2/1024/1024}' /proc/meminfo
command -v nvidia-smi >/dev/null 2>&1 && ok "nvidia-smi OK" || fail "nvidia-smi 없음"
docker info >/dev/null 2>&1 && ok "docker OK ($(docker --version))" || fail "docker daemon 불가"
command -v git >/dev/null 2>&1 && ok "git OK" || fail "git 없음"
command -v curl >/dev/null 2>&1 && ok "curl OK" || fail "curl 없음"
if command -v hf >/dev/null 2>&1 || command -v huggingface-cli >/dev/null 2>&1; then
  ok "huggingface cli 존재"
else
  warn "hf cli 없음 (4-download.sh 전 설치: pip install -U huggingface_hub)"
fi

mkdir -p "$DATA_ROOT/models" "$DATA_ROOT/input" "$DATA_ROOT/output"
AVAIL_GB=$(df -BG "$(readlink -f "$DATA_ROOT")" | awk 'NR==2{gsub("G","",$4); print $4}')
echo "DATA_ROOT=$DATA_ROOT avail=${AVAIL_GB}G"
[ "${AVAIL_GB:-0}" -ge 60 ] && ok "디스크 ${AVAIL_GB}G (모델 ~42.5GB 가능)" \
  || warn "디스크 ${AVAIL_GB}G < 60G"

if curl -s -m 2 "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1; then
  warn "port 8188 사용중 (기존 comfy 있으면 8/9-stop으로 정리)"
else
  ok "port 8188 비어있음"
fi

echo
echo "===== preflight: PASS=$PASS WARN=$WARN FAIL=$FAIL ====="
echo "다음: ./2-prepare-source.sh"
[ "$FAIL" -gt 0 ] && exit 1 || true
