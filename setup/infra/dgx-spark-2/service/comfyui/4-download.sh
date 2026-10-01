#!/usr/bin/env bash
# 4-download: H3 4종 모델 파일 (~42.5GB) + 검증. 실행 순서 4/9.
#   ./4-download.sh [fl2va|all]   (기본 fl2va; all은 Ref2VA diffusion 추가)
# 소스: Comfy-Org/MiniMax-H3 (ComfyUI가 미싱 파일 자동 fetch하는 그 리포)
set -euo pipefail

MODE="${1:-fl2va}"
DATA_ROOT="${DATA_ROOT:-$HOME/data/minimax-h3-comfyui}"
MODELS="$DATA_ROOT/models"
HF_REPO="Comfy-Org/MiniMax-H3"

mkdir -p "$MODELS"

# 정확한 4종 + Turbo LoRA (Xplore-LAB 검증 조합). 와일드카드 금지:
# diffusion *fl2va* 패턴은 bf16/w6a8/fp8 등 6종을 다 받아버림.
case "$MODE" in
  fl2va) FILES=(
    "diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
    "text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
    "vae/minimax_h3_video_vae_fp16.safetensors"
    "vae/minimax_h3_audio_vae_fp32.safetensors"
    "loras/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors"
  ) ;;
  all) FILES=(
    "diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
    "loras/minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors"
  ); echo "WARN: Ref2VA 추가분 다운로드" ;;
  *) echo "usage: $0 [fl2va|all]"; exit 2 ;;
esac

if command -v hf >/dev/null 2>&1; then DL="hf download"; else DL="huggingface-cli download"; fi
for f in "${FILES[@]}"; do
  [ -f "$MODELS/$f" ] && { echo "exists, skip: $f"; continue; }
  echo "== $f =="
  # shellcheck disable=SC2086
  (set -x; $DL "$HF_REPO" --include "$f" --local-dir "$MODELS")
done

echo "== 검증 =="
MISS=0
for f in "${FILES[@]}"; do
  [ -f "$MODELS/$f" ] && du -h "$MODELS/$f" || { echo "MISS: $f"; MISS=$((MISS+1)); }
done
du -sh "$MODELS"
[ "$MISS" -gt 0 ] && { echo "FAIL: $MISS 종 없음"; exit 1; }

echo
echo "OK: 모델 4종 확보"
echo "다음: ./5-up.sh"
