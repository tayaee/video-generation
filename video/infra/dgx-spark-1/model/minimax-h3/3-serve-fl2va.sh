#!/usr/bin/env bash
# 3-serve-fl2va: vLLM-Omni FL2VA 서버 기동 (공식 GB10 레시피).
# 출처: vllm-omni recipes/MiniMaxAI/MiniMax-H3-Spark-GB10.md (1x: 960x576/8s, FP8 필수, offload 금지)
# 실행 순서 3/9. single-tenant: 기존 h3 컨테이너 있으면 먼저 내린다.
set -euo pipefail

H3_ROOT="${H3_ROOT:-$HOME/models/MiniMax-H3}"
H3_PORT="${H3_PORT:-8000}"
IMAGE="${VLLM_OMNI_IMAGE:-vllm/vllm-omni:minimax-h3}"
# 공식 recipes.yaml 지시: 이미지 내장 vllm-omni는 구버전이라 체크아웃으로 override 필수.
# GB10 검증 리비전(e1aa6ea, vLLM 0.26.0 대응)으로 ./2-download.sh가
# ~/git/vllm-omni(canonical, read-only)에서 materialize한 plain copy를 마운트.
# 최신 main은 vLLM 0.28+ 전용이라 import 깨짐.
VLLM_OMNI_SRC="${VLLM_OMNI_SRC:-$HOME/tools/vllm-omni}"
NAME="h3-fl2va"
INIT_TIMEOUT="${INIT_TIMEOUT:-3600}"

[ -d "$H3_ROOT/FL2VA" ] || { echo "FAIL: $H3_ROOT/FL2VA 없음. ./2-download.sh FL2VA 먼저"; exit 1; }
[ -d "$VLLM_OMNI_SRC/vllm_omni" ] || { echo "FAIL: $VLLM_OMNI_SRC에 vllm-omni 소스 없음. ./2-download.sh 먼저"; exit 1; }

echo "== 기존 h3 컨테이너 정리 =="
(set -x; docker rm -f "$NAME" h3-ref2va 2>/dev/null) || true

echo "== docker run ($IMAGE, port $H3_PORT) =="
(set -x; docker run -d --name "$NAME" \
  --gpus all --privileged --ipc=host -p "$H3_PORT:8000" \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -v "$H3_ROOT:/model:ro" \
  -v "$VLLM_OMNI_SRC:/opt/vllm-omni:ro" \
  -e PYTHONPATH=/opt/vllm-omni \
  -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
  -e VLLM_OMNI_VIDEO_SYNC_TIMEOUT=7200 \
  -e FLASHINFER_DISABLE_VERSION_CHECK=1 \
  -e HF_HUB_OFFLINE=1 \
  "$IMAGE" vllm serve /model/FL2VA \
  --omni --trust-remote-code \
  --host 0.0.0.0 --port 8000 \
  --init-timeout "$INIT_TIMEOUT" \
  --num-gpus 1 --tensor-parallel-size 1 --text-encoder-tp-size 1 \
  --usp 1 --ring 1 --vae-patch-parallel-size 1 \
  --vae-parallel-mode tile --vae-use-tiling \
  --quantization fp8 --enforce-eager \
  --diffusion-attention-backend CUDNN_ATTN)

echo "== 기동 대기 (Application startup complete, 최대 ${INIT_TIMEOUT}s) =="
START=$(date +%s)
while true; do
  docker logs "$NAME" 2>&1 | grep -q "Application startup complete" && break
  if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "FAIL: 컨테이너 종료됨. 로그:"; docker logs "$NAME" 2>&1 | tail -30; exit 1
  fi
  NOW=$(date +%s)
  [ $((NOW-START)) -gt "$INIT_TIMEOUT" ] && { echo "FAIL: 기동 타임아웃"; exit 1; }
  sleep 15
done
curl -s -m 10 "http://127.0.0.1:$H3_PORT/health" -o /dev/null -w "health: %{http_code}\n" || true

echo
echo "OK: FL2VA serving on :$H3_PORT"
echo "다음: ./4-smoke-t2va.sh"
