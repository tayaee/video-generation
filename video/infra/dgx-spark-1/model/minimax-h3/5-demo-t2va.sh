#!/usr/bin/env bash
# 5-demo-t2va: 쌈빡 데모 3종 배치 (FL2VA). 실행 순서 5/9.
# DEMO_STEPS 기본 50 (풀퀄, 편당 ~36분) / 맛보기면 DEMO_STEPS=10 (~2분).
set -euo pipefail

H3_PORT="${H3_PORT:-8000}"
STEPS="${DEMO_STEPS:-50}"
# 양산 결과는 /rosenas/data/AIML/video-generation/results/<slug>/ 에 저장 (빈값이면 로컬).
RESULTS_ROOT="${RESULTS_ROOT-/rosenas/data/AIML/video-generation/results}"
if [ -n "$RESULTS_ROOT" ]; then OUTDIR="$RESULTS_ROOT/demo";
else OUTDIR="$(dirname "$0")/outputs"; fi
mkdir -p "$OUTDIR"
[ -w "$OUTDIR" ] || { echo "FAIL: 쓰기 불가: $OUTDIR"; exit 1; }
TS=$(date +%Y%m%d_%H%M%S)

curl -s -m 5 "http://127.0.0.1:$H3_PORT/health" >/dev/null \
  || { echo "FAIL: 서버 없음. ./3-serve-fl2va.sh 먼저"; exit 1; }

run_one() { # name prompt duration width height
  local name="$1" prompt="$2" dur="$3" w="$4" h="$5"
  local out="$OUTDIR/${TS}_${name}_s${STEPS}.mp4"
  echo "===== $name (${w}x${h}, ${dur}s, ${STEPS} steps) ====="
  (set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
    -F "prompt=$prompt" \
    -F "width=$w" -F "height=$h" -F 'aspect_ratio=16:9' \
    -F 'fps=24' -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F 'seed=1101' \
    -F "extra_params={\"task\":\"t2va\",\"duration\":$dur,\"audio_flow_shift\":3.0}" \
    --max-time 7200 -o "$out" -w 'e2e=%{time_total}s\n')
  ls -lh "$out"
}

# 1) 공식 검증 프롬프트 (베이스라인)
run_one "cats_brass" \
  "At night, three cats march into a bedroom playing tiny brass instruments, then abruptly file out, with synchronized room ambience." \
  8.0 960 576

# 2) 대사+립싱크 (H3 강점: 네이티브 스테레오)
run_one "seoul_vendor" \
  "Close-up of a street vendor in a neon-lit Seoul alley on a rainy night, he looks at the camera and says fresh hotteok, two for a dollar, sizzling grill sounds, rain patter, distant traffic hum." \
  5.0 960 576

# 3) 텍스트 렌더링 (따옴표 대신 풀네임 명시: H3는 인용부호보다 열거가 잘 먹힘)
run_one "espresso_brand" \
  "Macro shot of a frosted glass bottle labeled HALEU ESPRESSO on a wet cafe table, slow dolly-in, espresso machine hiss, clinking cups, lo-fi jazz underneath." \
  5.0 960 576

echo
echo "outputs: $OUTDIR/${TS}_*.mp4"
echo "다음: Ref2VA 원하면 ./6-serve-ref2va.sh (FL2VA 내리고 갈아탐)"
