#!/usr/bin/env bash
# 9-stop-all: 전체 종료 (vllm + comfyui + 상태 요약). 실행 순서 9/9 (종료 트랙 2/2).
set -euo pipefail

BASEDIR="$(dirname "$0")"
(set -x; "$BASEDIR/8-stop-vllm.sh") || true

echo "== comfyui 정지 =="
if docker ps -a --format '{{.Names}}' | grep -qx "h3-comfyui"; then
  (set -x; docker stop h3-comfyui >/dev/null && docker rm h3-comfyui >/dev/null) && echo "removed: h3-comfyui"
else
  echo "skip (없음): h3-comfyui"
fi

echo "== 포트 =="
for P in 8000 8188; do
  if curl -s -m 2 "http://127.0.0.1:$P/health" >/dev/null 2>&1 \
    || curl -s -m 2 "http://127.0.0.1:$P/system_stats" >/dev/null 2>&1; then
    echo "port $P: 아직 응답 있음 (수동 확인 필요)"
  else
    echo "port $P: 비어있음"
  fi
done

echo "== 메모리 =="
awk '/MemAvailable/{printf "MemAvailable: %.1f GiB\n", $2/1024/1024}' /proc/meminfo 2>/dev/null || true

echo
echo "DONE: minimax-h3 전체 정지"
