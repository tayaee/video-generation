#!/usr/bin/env bash
# 8-stop: ComfyUI 컨테이너 정지/삭제. 실행 순서 8/9 (종료 트랙 1/2).
set -euo pipefail

NAME="h3-comfyui"
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "== stop+rm $NAME =="
  (set -x; docker stop "$NAME" >/dev/null && docker rm "$NAME" >/dev/null) && echo "removed: $NAME"
else
  echo "skip (없음): $NAME"
fi

docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -i comfy || echo "(comfy 없음, 깨끗함)"

echo
echo "다음: ./9-stop-all.sh (vllm 포함 전체 정리)"
