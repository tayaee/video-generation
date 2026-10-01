#!/usr/bin/env bash
# 7-demo-ref2va: 레퍼런스 이미지 1장 기반 Ref2VA 데모. 실행 순서 7/9.
# REF_IMAGE 미지정시 outputs/ 최신 mp4에서 프레임 자동 추출 (없으면 에러+안내).
# ref2va는 aspect_ratio 생략 가능. 50스텝 약 69분, STEPS=10 맛보기 가능.
set -euo pipefail

H3_PORT="${H3_PORT:-8000}"
STEPS="${STEPS:-50}"
BASEDIR="$(dirname "$0")"
OUTDIR="$BASEDIR/outputs"
REFDIR="$BASEDIR/refs"
mkdir -p "$OUTDIR" "$REFDIR"
TS=$(date +%Y%m%d_%H%M%S)
PROMPT="${PROMPT:-A hand rests on a wooden table in warm evening light, then slowly opens and turns toward the camera, with quiet room ambience.}"

curl -s -m 5 "http://127.0.0.1:$H3_PORT/health" >/dev/null \
  || { echo "FAIL: 서버 없음. ./6-serve-ref2va.sh 먼저"; exit 1; }

REF_IMAGE="${REF_IMAGE:-}"
if [ -z "$REF_IMAGE" ]; then
  LATEST=$(ls -t "$OUTDIR"/*.mp4 2>/dev/null | head -1 || true)
  [ -n "${LATEST:-}" ] || { echo "FAIL: REF_IMAGE 미지정 + outputs에 mp4 없음. refs/에 레퍼런스 jpg를 넣고 REF_IMAGE=refs/xxx.jpg 로 재실행"; exit 1; }
  command -v ffmpeg >/dev/null 2>&1 || { echo "FAIL: ffmpeg 없음. REF_IMAGE 직접 지정 필요"; exit 1; }
  REF_IMAGE="$REFDIR/auto_ref_$TS.jpg"
  echo "== $LATEST 에서 1s 프레임 추출 -> $REF_IMAGE =="
  (set -x; ffmpeg -v error -y -ss 1 -i "$LATEST" -frames:v 1 "$REF_IMAGE")
fi
[ -f "$REF_IMAGE" ] || { echo "FAIL: 레퍼런스 없음: $REF_IMAGE"; exit 1; }

OUT="$OUTDIR/${TS}_ref2va_s${STEPS}.mp4"
echo "== Ref2VA (960x576, 8s, $STEPS steps, ref=$REF_IMAGE) =="
(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
  --max-time 14400 \
  -F "input_reference=@${REF_IMAGE};type=image/jpeg" \
  -F "prompt=${PROMPT}" \
  -F 'width=960' -F 'height=576' -F 'fps=24' \
  -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F 'seed=1101' \
  -F 'extra_params={"task":"ref2va","duration":8.0,"audio_flow_shift":3.0}' \
  -o "$OUT" -w 'e2e=%{time_total}s\n')

ls -lh "$OUT"
command -v ffprobe >/dev/null 2>&1 && \
  ffprobe -v error -show_entries stream=index,codec_name,width,height,r_frame_rate,sample_rate,channels \
    -of default=noprint_wrappers=1 "$OUT" || true

echo
echo "다음: ./8-stop-vllm.sh (서버 정리)"
