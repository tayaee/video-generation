#!/usr/bin/env bash
# 8-stop-vllm: vLLM-Omni h3 컨테이너 정지/삭제. 실행 순서 8/9 (종료 트랙 1/2).
set -euo pipefail

for N in h3-fl2va h3-ref2va; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$N"; then
    echo "== stop+rm $N =="
    (set -x; docker stop "$N" >/dev/null && docker rm "$N" >/dev/null) && echo "removed: $N"
  else
    echo "skip (없음): $N"
  fi
done

echo "== 잔여 h3 컨테이너 =="
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -i h3 || echo "(없음, 깨끗함)"

echo
echo "다음: ./9-stop-all.sh (comfyui 포함 전체 정리)"
