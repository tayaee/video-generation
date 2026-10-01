#!/usr/bin/env bash
# 4-smoke-t2va: 10스텝 스모크 (약 96초). 실행 순서 4/9.
# t2va는 width/height를 줘도 aspect_ratio 명시가 필수 (없으면 OmniClientError).
set -euo pipefail

H3_PORT="${H3_PORT:-8000}"
# 양산 결과는 /rosenas/data/AIML/comfyui/results/<slug>/ 에 저장 (빈값이면 로컬).
RESULTS_ROOT="${RESULTS_ROOT-/rosenas/data/AIML/comfyui/results}"
if [ -n "$RESULTS_ROOT" ]; then OUTDIR="$RESULTS_ROOT/smoke";
else OUTDIR="$(dirname "$0")/outputs"; fi
mkdir -p "$OUTDIR"
[ -w "$OUTDIR" ] || { echo "FAIL: 쓰기 불가: $OUTDIR"; exit 1; }
OUT="$OUTDIR/smoke_t2va_$(date +%Y%m%d_%H%M%S).mp4"

curl -s -m 5 "http://127.0.0.1:$H3_PORT/health" >/dev/null \
  || { echo "FAIL: 서버 없음. ./3-serve-fl2va.sh 먼저"; exit 1; }

echo "== smoke T2VA (960x576, 4s, 10 steps) =="
(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
  -F 'prompt=At night, three cats march into a bedroom playing tiny brass instruments, then abruptly file out, with synchronized room ambience.' \
  -F 'width=960' -F 'height=576' -F 'aspect_ratio=16:9' \
  -F 'fps=24' -F 'num_inference_steps=10' -F 'flow_shift=12' -F 'seed=1101' \
  -F 'extra_params={"task":"t2va","duration":4.0,"audio_flow_shift":3.0}' \
  --max-time 7200 \
  -o "$OUT")

echo "== 검증 =="
ls -lh "$OUT"
command -v ffprobe >/dev/null 2>&1 && \
  ffprobe -v error -show_entries stream=index,codec_name,width,height,r_frame_rate,sample_rate,channels \
    -of default=noprint_wrappers=1 "$OUT" || echo "(ffprobe 없음, 스킵)"

echo
echo "다음: ./5-demo-t2va.sh  (풀퀄 50스텝, 편당 ~36분)"
