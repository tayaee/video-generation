#!/usr/bin/env bash
# showcase/matchgirl/generate.sh: 5분 벤치마크 필름 샷 생성 (20샷 x 15s = 300s).
# 원작: 안데르센 '성냥팔이 소녀' 축약 (public domain). 실사(photoreal) 지정.
# 정합성 수단: 매 프롬프트에 캐릭터 바이블(GIRL) verbatim + MODE=chain 시
#   이전 샷 끝프레임을 ref2va 레퍼런스로.
#   ./generate.sh            # t2va STEPS=10 프리뷰 (하룻밤 러닝 권장)
#   STEPS=50 ./generate.sh   # 풀퀄 (편당 수십 분)
#   MODE=chain ./generate.sh # 정합성 우선 (ref2va 체이닝)
#   LIST=1 ./generate.sh     # 샷 목록만 출력 (생성 안 함)
#   DUR=8 ./generate.sh      # 15s 실패 시 폴백 (총 160s 단축판)
#   COUNT=1 DUR=5 ./generate.sh # smoke: 첫 샷만 5초 (서빙 검증용)
# 존재하는 샷은 검증 후 스킵하므로 중단→재실행이 resume이 된다.
set -euo pipefail

H3_PORT="${H3_PORT:-8000}"
STEPS="${STEPS:-10}"
DUR="${DUR:-15}"
MODE="${MODE:-t2va}"
LIST="${LIST:-0}"
COUNT="${COUNT:-0}"
BASEDIR="$(dirname "$0")"
# 양산 결과는 /rosenas/data/AIML/comfyui/results/<slug>/ 에 저장 (빈값이면 로컬).
RESULTS_ROOT="${RESULTS_ROOT-/rosenas/data/AIML/comfyui/results}"
if [ -n "$RESULTS_ROOT" ]; then OUTDIR="${OUTDIR:-$RESULTS_ROOT/matchgirl/shots}";
else OUTDIR="${OUTDIR:-$BASEDIR/shots}"; fi
TIMINGS="$OUTDIR/timings.csv"
FRAME="$OUTDIR/.chain_last.jpg"

GIRL="a barefoot girl of about nine with reddish-gold hair under a patched gray coat, clutching a bundle of matchboxes"

SHOTS=(
"01_dusk_street|Photorealistic period film, New Year Eve dusk, snow falling on a cobblestone street. ${GIRL} hugs a brick wall, breath fogging. Warm windows glow across the street. Slow dolly-in. Wind howl, distant church bells, crunching snow under boots."
"02_barefoot_snow|Photorealistic close-up, small bare feet stepping into fresh snow, toes red with cold. ${GIRL} hurries past shuttered shops. Handheld follow. Snow crunch, ragged breathing, a far-off children's choir rehearsing a carol in Korean, wind gusts."
"03_unsold_matches|Photorealistic street level, frost-covered bundle of matchboxes in small hands. ${GIRL} holds them up to hurrying passersby legs, no one stops. Static then slight tilt down. Muffled footsteps fading, coins clinking elsewhere, sighing wind."
"04_window_feast|Photorealistic warm restaurant window at night, diners silhouetted around a feast. ${GIRL} watches from the snowy dark outside, nose near glass. Slow push-in. Muffled laughter and clinking cutlery behind glass, cold wind outside."
"05_first_strike|Photorealistic dark alley corner, ${GIRL} crouches and strikes a match against the wall. Sudden flare blooms across her face. Macro of the flame catching. Sharp hiss, held breath, then soft crackle, wind dropping away."
"06_stove_vision|Photorealistic dream vision, a great iron stove glowing with brass ornaments, radiant heat waves. ${GIRL} stretches frozen hands toward it, smiling. Slow orbit. Deep fire crackle, metallic ticks, warm low hum."
"07_vision_dies|Photorealistic, the stove vision gutters and dissolves back into a bare cold wall. ${GIRL} stares at the dead match, smile fading. Match cut to wide. Flame sputter, cold wind rushing back, faint whimper."
"08_cold_returns|Photorealistic, ${GIRL} shivering hard in the alley, wrapping the coat tighter, teeth chattering, deciding on a second match. Trembling close-up. Chattering teeth, shuddering breaths, snow hissing on stone."
"09_second_strike|Photorealistic, a second match flares against the brick, brighter, lighting falling snowflakes like sparks. ${GIRL} gasps. Slow motion flare. Strike scrape, whoosh of flame, tiny awed gasp."
"10_goose_vision|Photorealistic dream vision, a roast goose steaming on a white tablecloth, stuffing and apples, carving knife gleaming. ${GIRL} leans in wide-eyed. Push-in. Rich sizzle, clink of the knife, warm room tone."
"11_goose_rises|Photorealistic dream logic, the roast goose rises with knife and fork in its breast and waddles toward the poor child. ${GIRL} laughs in delight. Gentle tracking. Playful sizzle, soft child laughter, music-box notes."
"12_dark_again|Photorealistic, the vision snaps to black alley, snow falling harder. ${GIRL} alone again under a street lamp. Crane up. Cutoff of music, heavy snowfall hush, distant midnight bells."
"13_third_strike|Photorealistic, a third match bursts into a tall steady flame cupped in both hands. ${GIRL} face glowing amber. Low angle. Strong flare-up, cupped-hands warmth tone, snow sizzling."
"14_tree_vision|Photorealistic dream vision, a towering Christmas tree covered in lit candles and painted ornaments. ${GIRL} reaches up in wonder. Slow tilt up. Soft Korean choir, candle sizzle, ornament glass chimes."
"15_candles_rise|Photorealistic, the tree candles detach and rise into the night sky as stars. ${GIRL} watches, mouth open. Tilt to sky. Korean choir swelling, rising shimmer tone, wind fading to silence."
"16_falling_star|Photorealistic night sky, one star detaches and falls. ${GIRL} whispers to the dark in Korean, 오늘 밤 누군가 죽어. Extreme close-up on eyes. Hushed Korean whisper, long reverb tail, total stillness."
"17_bundle_blaze|Photorealistic, ${GIRL} strikes the whole bundle at once, a bright roaring blaze lighting the whole alley like noon. Wide shot. Roaring flare, crackling storm of matches, heartbeat drum."
"18_grandmother|Photorealistic radiant vision, her grandmother appears in warm light, arms open, kindest face, murmuring in Korean, 이제 따뜻할 거야. ${GIRL} runs into the embrace. Slow motion. Soft Korean murmur and humming lullaby, warmest room tone, faint Korean choir."
"19_ascent|Photorealistic ascent above snowy rooftops, the grandmother carrying ${GIRL} upward, town shrinking below, snowflakes hanging still. Crane soaring. Korean choir and heartbeat slowing together, then quiet."
"20_dawn_smile|Photorealistic dawn square, ${GIRL} leaning on the wall with a smile, cheeks rosy, burnt matches scattered. Morning light blooms. Slow pull-back. Morning bells, approaching footsteps, birdsong, gentle thaw drip."
)

# COUNT>0이면 앞 N샷만 (smoke용). LIST·EXPECT·resume 로직이 자동 추종.
[ "${COUNT:-0}" -gt 0 ] 2>/dev/null && SHOTS=("${SHOTS[@]:0:$COUNT}") || true

dur_ok() { # file
  local got
  got=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null || echo 0)
  awk -v d="$got" -v e="$DUR" 'BEGIN{exit !(d>=e-2 && d<=e+15)}'
}

if [ "$LIST" = "1" ]; then
  echo "outdir: $OUTDIR"
  n=0
  for entry in "${SHOTS[@]}"; do
    n=$((n+1)); printf '%02d %s (%ss)\n' "$n" "${entry%%|*}" "$DUR"
  done
  echo "total: $n shots x ${DUR}s = $((n * DUR))s (mode=$MODE, steps=$STEPS)"
  exit 0
fi

curl -s -m 5 "http://127.0.0.1:$H3_PORT/health" >/dev/null \
  || { echo "FAIL: 서버 없음. ./3-serve-fl2va.sh 또는 ./6-serve-ref2va.sh 먼저"; exit 1; }
mkdir -p "$OUTDIR"
[ -w "$OUTDIR" ] || { echo "FAIL: 쓰기 불가: $OUTDIR (sudo mkdir -p $OUTDIR && sudo chown -R $(whoami) $OUTDIR)"; exit 1; }
[ -f "$TIMINGS" ] || echo "shot,id,steps,dur_s,e2e_s" > "$TIMINGS"

n=0
for entry in "${SHOTS[@]}"; do
  n=$((n+1))
  id="${entry%%|*}"
  prompt="${entry#*|}"
  out="$OUTDIR/$(printf '%02d' "$n")_${id#[0-9][0-9]_}_s${STEPS}.mp4"
  seed=$((1101 + n))
  if [ -f "$out" ] && dur_ok "$out"; then
    echo "===== [$n/${#SHOTS[@]}] $id: skip exists ====="
  else
    echo "===== [$n/${#SHOTS[@]}] $id (${DUR}s, $STEPS steps, mode=$MODE) ====="
    if [ "$MODE" = "chain" ] && [ "$n" -gt 1 ] && [ -f "$FRAME" ]; then
      E2E=$(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
        --max-time 14400 \
        -F "input_reference=@${FRAME};type=image/jpeg" \
        -F "prompt=${prompt}" \
        -F 'width=960' -F 'height=576' -F 'fps=24' \
        -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F "seed=$seed" \
        -F "extra_params={\"task\":\"ref2va\",\"duration\":$DUR,\"audio_flow_shift\":3.0}" \
        -o "$out" -w '%{time_total}')
    else
      E2E=$(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
        -F "prompt=${prompt}" \
        -F 'width=960' -F 'height=576' -F 'aspect_ratio=16:9' \
        -F 'fps=24' -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F "seed=$seed" \
        -F "extra_params={\"task\":\"t2va\",\"duration\":$DUR,\"audio_flow_shift\":3.0}" \
        --max-time 7200 -o "$out" -w '%{time_total}')
    fi
    echo "$n,$id,$STEPS,$DUR,$E2E" >> "$TIMINGS"
    ls -lh "$out"
  fi
  dur_ok "$out" || { echo "FAIL: 길이 이상: $out"; exit 1; }
  if [ "$MODE" = "chain" ]; then
    (set -x; ffmpeg -v error -y -sseof -3 -i "$out" -frames:v 1 "$FRAME")
  fi
done

echo "== 합산 검증 =="
TOTAL=$(for f in "$OUTDIR"/*.mp4; do
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f"
done | awk '{s+=$1} END{printf "%.1f", s}')
EXPECT=$((${#SHOTS[@]} * DUR))
echo "shots: ${#SHOTS[@]}, total: ${TOTAL}s (expect ~${EXPECT}s)"
echo "timings: $TIMINGS"
echo
echo "다음: ../assemble.sh \"$OUTDIR\""
