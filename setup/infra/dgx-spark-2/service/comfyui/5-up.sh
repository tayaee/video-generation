#!/usr/bin/env bash
# 5-up: ComfyUI 컨테이너 기동 (:8188). 실행 순서 5/9.
# IMAGE env로 이미지 교체 가능 (6-fix-torchaudio.sh가 고정 이미지로 재기동할 때 사용).
set -euo pipefail

DATA_ROOT="${DATA_ROOT:-$HOME/data/minimax-h3-comfyui}"
IMAGE="${IMAGE:-local/minimax-h3-comfyui:v0.30.0}"
NAME="h3-comfyui"
TIMEOUT="${UP_TIMEOUT:-600}"

mkdir -p "$DATA_ROOT/models" "$DATA_ROOT/input" "$DATA_ROOT/output"
(set -x; docker rm -f "$NAME" 2>/dev/null) || true

echo "== docker run ($IMAGE) =="
(set -x; docker run -d --name "$NAME" \
  --gpus all --ipc=host -p 8188:8188 \
  -v "$DATA_ROOT/models:/comfyui/models" \
  -v "$DATA_ROOT/input:/comfyui/input" \
  -v "$DATA_ROOT/output:/comfyui/output" \
  "$IMAGE")

echo "== GUI 대기 (http://0.0.0.0:8188, 최대 ${TIMEOUT}s) =="
START=$(date +%s)
while true; do
  curl -s -m 5 "http://127.0.0.1:8188/system_stats" >/dev/null 2>&1 && break
  if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "FAIL: 컨테이너 종료됨. 로그:"; docker logs "$NAME" 2>&1 | tail -30; exit 1
  fi
  NOW=$(date +%s)
  [ $((NOW-START)) -gt "$TIMEOUT" ] && { echo "FAIL: 기동 타임아웃"; docker logs "$NAME" 2>&1 | tail -20; exit 1; }
  sleep 10
done

echo "OK: ComfyUI http://127.0.0.1:8188"
echo "다음: ./6-fix-torchaudio.sh  (최초 1회, 오디오 VAE 필수)"
