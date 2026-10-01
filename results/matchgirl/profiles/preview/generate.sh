#!/usr/bin/env bash
# results/matchgirl/profiles/preview/generate.sh: 5분 단편 프리뷰 (36샷 x 8s = 288s, STEPS=10).
# (full 프로파일은 profiles/full/generate.sh — STEPS=50. STEPS/DUR/MODE/COUNT env로 조정 가능)
# DUR 기본값 8은 GB10 공식 검증 스펙(960x576/8s). 15s는 서버 한계 초과로 사용 금지
# (15s 요청이 diffusion 워커를 멈추고 2시간 타임아웃으로만 죽는 것 확인됨, 2026-10-01).
# 원작: 안데르센 '성냥팔이 소녀' 축약 (public domain). 실사(photoreal) 지정.
# 5막 완결: 막1 새해 전날 거리 / 막2 첫 성냥·난로 / 막3 두 번째·거위 /
#   막4 세 번째·트리 / 막5 마지막 다발·할머니·새해 아침.
# 정합성 수단: 매 프롬프트에 캐릭터 바이블(GIRL) verbatim + MODE=chain 시
#   이전 샷 끝프레임을 ref2va 레퍼런스로 (ref2va 서버 기동 시에만 유효).
#   ./generate.sh            # t2va 프리뷰 (STEPS/DUR/MODE/COUNT env로 조정 가능)
#   MODE=chain ./generate.sh # 정합성 우선 (ref2va 체이닝, 6-serve-ref2va.sh 서버 필요)
#   LIST=1 ./generate.sh     # 샷 목록만 출력 (생성 안 함)
#   COUNT=1 DUR=5 ./generate.sh # smoke: 첫 샷만 5초 (서빙 검증용)
# 존재하는 샷은 검증 후 스킵하므로 중단→재실행이 resume이 된다.
set -euo pipefail

H3_PORT="${H3_PORT:-8000}"
STEPS="${STEPS:-10}"
DUR="${DUR:-8}"
MODE="${MODE:-t2va}"
LIST="${LIST:-0}"
COUNT="${COUNT:-0}"
BASEDIR="$(dirname "$0")"
# 산출물은 프로파일 디렉토리 안 shots/ (리포 Primary, NAS는 sync-results.sh로 복사).
OUTDIR="${OUTDIR:-$BASEDIR/shots}"
TIMINGS="$OUTDIR/timings.csv"
FRAME="$OUTDIR/.chain_last.jpg"

GIRL="a barefoot girl of about nine with reddish-gold hair under a patched gray coat, clutching a bundle of matchboxes"

SHOTS=(
# ── 막1: 새해 전날 (아침 출발 → 해질녘 거리) ──
"01_morning_attic|Photorealistic dawn attic room, frost on the inside of a small window. ${GIRL} wraps a thin shawl, tucks the match bundle inside her coat, and steps out into the cold morning. Slow pull-back. Floorboard creaks, thin blanket rustle, distant rooster, cold wind under the door."
"02_lost_slippers|Photorealistic snowy morning street, two carriages thunder past. ${GIRL} stumbles in oversized slippers, one flies off and a running boy snatches it up laughing, gone around the corner. Handheld panic. Horse hooves, wheel rattle, boy laughter fading, her small cry in Korean, 내 신발!"
"03_dusk_street|Photorealistic period film, New Year Eve dusk, snow falling on a cobblestone street. ${GIRL} holds up her matches to hurrying passersby and calls out in Korean, 성냥 사세요, breath fogging. Warm windows glow across the street. Slow dolly-in. Faint Korean street cry, wind howl, distant church bells, crunching snow under boots."
"04_barefoot_snow|Photorealistic close-up, small bare feet stepping into fresh snow, toes red with cold. ${GIRL} hurries past shuttered shops. Handheld follow. Snow crunch, ragged breathing, a far-off children's choir rehearsing a carol in Korean, wind gusts."
"05_unsold_matches|Photorealistic street level, frost-covered bundle of matchboxes in small hands. ${GIRL} holds them up to hurrying passersby legs, no one stops. Static then slight tilt down. Muffled footsteps fading, coins clinking elsewhere, sighing wind."
"06_rich_family|Photorealistic, a wealthy family in furs hurries past with parcels and a toy horse. ${GIRL} reaches out her matches, the mother pulls her child away without a glance. Slow motion pass. Muffled rich laughter, sleigh bells, her whisper in Korean, 하나만 사주세요."
"07_window_feast|Photorealistic warm restaurant window at night, diners silhouetted around a feast. ${GIRL} watches from the snowy dark outside, nose near glass. Slow push-in. Muffled laughter and clinking cutlery behind glass, cold wind outside."
# ── 막2: 첫 성냥 · 난로 ──
"08_no_home|Photorealistic, ${GIRL} looks back toward a lit alley where home would be, then shakes her head and crouches between two houses, afraid of her father's switch with no money earned. Trembling close-up. Her chattering whisper in Korean, 빈손으론 못 돌아가, snow hissing on stone."
"09_first_strike|Photorealistic dark alley corner, ${GIRL} crouches and strikes a match against the wall. Sudden flare blooms across her face. Macro of the flame catching. Sharp hiss, held breath, then soft crackle, wind dropping away."
"10_stove_vision|Photorealistic dream vision, a great iron stove glowing with brass ornaments, radiant heat waves. ${GIRL} stretches frozen hands toward it, smiling. Slow orbit. Deep fire crackle, metallic ticks, warm low hum."
"11_warm_hands|Photorealistic close-up inside the vision, her small red hands open before the glowing stove grate, frost melting off her fingertips into steam. ${GIRL} sighs with relief. Extreme macro. Steam hiss, soft relieved sigh in Korean, 따뜻해."
"12_vision_dies|Photorealistic, the stove vision gutters and dissolves back into a bare cold wall. ${GIRL} stares at the dead match, smile fading. Match cut to wide. Flame sputter, cold wind rushing back, faint whimper."
"13_cold_returns|Photorealistic, ${GIRL} shivering hard in the alley, wrapping the coat tighter, teeth chattering, deciding on a second match. Trembling close-up. Chattering teeth, shuddering breaths, snow hissing on stone."
# ── 막3: 두 번째 · 거위 ──
"14_second_strike|Photorealistic, a second match flares against the brick, brighter, lighting falling snowflakes like sparks. ${GIRL} gasps. Slow motion flare. Strike scrape, whoosh of flame, tiny awed gasp."
"15_goose_vision|Photorealistic dream vision, a roast goose steaming on a white tablecloth, stuffing and apples, carving knife gleaming. ${GIRL} leans in wide-eyed. Push-in. Rich sizzle, clink of the knife, warm room tone."
"16_goose_rises|Photorealistic dream logic, the roast goose rises with knife and fork in its breast and waddles toward the poor child. ${GIRL} laughs in delight. Gentle tracking. Playful sizzle, soft child laughter, music-box notes."
"17_almost_taste|Photorealistic, ${GIRL} reaches both hands for the waddling goose, mouth open, and the vision bursts like a soap bubble into cold sparks. Her smile freezes. Rack focus. Bubble pop, cold rush, tiny disappointed cry."
"18_dark_again|Photorealistic, the vision snaps to black alley, snow falling harder. ${GIRL} alone again under a street lamp. Crane up. Cutoff of music, heavy snowfall hush, distant midnight bells."
"19_blizzard|Photorealistic whiteout gust through the alley, ${GIRL} staggers, shields the bundle inside her coat, snow plastering her reddish-gold hair. Low angle struggle. Blizzard roar, coat flapping, her strained breath."
"20_last_matches|Photorealistic close-up, ${GIRL} opens the bundle with numb fingers and counts the last matches, three left, frost on the box labels. Shallow focus. Cardboard rub, finger tremble foley, wind underneath."
# ── 막4: 세 번째 · 트리 ──
"21_third_strike|Photorealistic, a third match bursts into a tall steady flame cupped in both hands. ${GIRL} face glowing amber. Low angle. Strong flare-up, cupped-hands warmth tone, snow sizzling."
"22_tree_vision|Photorealistic dream vision, a towering Christmas tree covered in lit candles and painted ornaments. ${GIRL} reaches up in wonder. Slow tilt up. Soft Korean choir, candle sizzle, ornament glass chimes."
"23_ornaments|Photorealistic inside the vision, glass ornaments reflect her wondering face a hundredfold as ${GIRL} touches one gently and it rings. Slow drift. Glass chime, her delighted whisper in Korean, 예쁘다."
"24_candles_rise|Photorealistic, the tree candles detach and rise into the night sky as stars. ${GIRL} watches, mouth open. Tilt to sky. Korean choir swelling, rising shimmer tone, wind fading to silence."
"25_falling_star|Photorealistic night sky, one star detaches and falls. ${GIRL} whispers to the dark in Korean, 오늘 밤 누군가 죽어. Extreme close-up on eyes. Hushed Korean whisper, long reverb tail, total stillness."
"26_grandmother_memory|Photorealistic warm flashback, her beloved grandmother lifts the laughing child onto her lap by a fireplace, the only face that ever loved her. ${GIRL} as a small child giggles. Soft slow motion. Fireplace crackle, kind humming, child giggle."
"27_bundle_decision|Photorealistic back in the frozen alley, ${GIRL} looks at the last matches, then at the sky where the star fell, and presses the whole bundle together with sudden resolve. Close-up on eyes. Heartbeat rising, matchbox shake, resolve breath."
# ── 막5: 마지막 다발 · 할머니 · 새해 아침 ──
"28_bundle_blaze|Photorealistic, ${GIRL} strikes the whole bundle at once, a bright roaring blaze lighting the whole alley like noon. Wide shot. Roaring flare, crackling storm of matches, heartbeat drum."
"29_grandmother|Photorealistic radiant vision, her grandmother appears in warm light, arms open, kindest face, murmuring in Korean, 이제 따뜻할 거야. ${GIRL} runs into the embrace. Slow motion. Soft Korean murmur and humming lullaby, warmest room tone, faint Korean choir."
"30_embrace|Photorealistic inside the blaze, the grandmother wraps ${GIRL} in her shawl, the child sobbing with joy, snowflakes turning to sparks around them. Slow orbit. Shawl fabric, joyful sobs, choir warming."
"31_ascent|Photorealistic ascent above snowy rooftops, the grandmother carrying ${GIRL} upward, town shrinking below, snowflakes hanging still. Crane soaring. Korean choir and heartbeat slowing together, then quiet."
"32_among_stars|Photorealistic, the grandmother and ${GIRL} drift among gentle stars, the child asleep on her shoulder, utterly at peace. Weightless drift. Choir dissolving to silence, one soft bell."
"33_dawn_alley|Photorealistic cold dawn, the alley lies empty and blue. ${GIRL} leans against the wall under thin snow, still, the burnt bundle beside her. Slow descent from sky to street. Dawn wind, far-off cock crow, emptiness."
"34_dawn_smile|Photorealistic dawn close-up, her small face with a peaceful smile, cheeks rosy, one burnt match still between her fingers. ${GIRL} rests forever warm in the vision. Static reverent close-up. Morning stillness, faint thaw drip."
"35_found_bells|Photorealistic, morning passersby gather and kneel around her, a woman covers her with a shawl, church bells ring the New Year. ${GIRL} is found smiling. Rising crane. Church bells, murmuring crowd, a woman's soft sob in Korean, 불쌍해서 어째."
"36_new_year|Photorealistic New Year morning wide, sun breaks over snowy rooftops, children run laughing with new toys past the quiet alley, light blooming over the town. Slow pull-back to sky. Children laughter, morning bells, birdsong, thaw dripping into the new year."
)

# COUNT>0이면 앞 N샷만 (smoke용). LIST·EXPECT·resume 로직이 자동 추종.
[ "${COUNT:-0}" -gt 0 ] 2>/dev/null && SHOTS=("${SHOTS[@]:0:$COUNT}") || true

dur_ok() { # file
  local got
  got=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null || echo 0)
  awk -v d="$got" -v e="$DUR" 'BEGIN{exit !(d>=e-2 && d<=e+15)}'
}

mem_snapshot() { # "used_MB available_MB swap_used_MB" 출력
  awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2} \
    END{printf "%d %d %d", (t-a)/1024, a/1024, (st-sf)/1024}' /proc/meminfo 2>/dev/null || echo "0 0 0"
}

gpu_temp() { # GPU 온도(℃) 출력, 실패 시 unknown
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' \n' || echo unknown
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

# 서버 모델명 캐시 (sidecar용, 실패 시 unknown).
H3_MODEL="$(curl -s -m 5 "http://127.0.0.1:$H3_PORT/v1/models" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["id"])' 2>/dev/null || echo unknown)"

write_sidecar() { # out task e2e prompt seed — 생성 직후 <stem>.json 기록
  local out="$1" task="$2" e2e="$3" prompt="$4" seed="$5"
  SC_OUT="$out" SC_TASK="$task" SC_E2E="$e2e" SC_PROMPT="$prompt" SC_SEED="$seed" \
  SC_URL="http://127.0.0.1:$H3_PORT" SC_MODEL="$H3_MODEL" SC_MODE="$MODE" \
  SC_PROFILE="$(basename "$(cd "$BASEDIR" && pwd)")" SC_STEPS="$STEPS" SC_DUR="$DUR" \
  SC_HOST="$(hostname 2>/dev/null || echo unknown)" \
  SC_GPU="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo unknown)" \
  SC_GIT="$(git -C "$BASEDIR" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
  SC_DATE="$(date -u +%FT%TZ)" \
  SC_MEM_BU="${MEM_BU:-0}" SC_MEM_BA="${MEM_BA:-0}" SC_MEM_AU="${MEM_AU:-0}" \
  SC_MEM_AA="${MEM_AA:-0}" SC_SWAP_B="${MEM_SWAP_B:-0}" SC_SWAP_A="${MEM_SWAP_A:-0}" \
  SC_GPU_TB="${GPU_TB:-unknown}" SC_GPU_TA="${GPU_TA:-unknown}" \
  python3 - <<'PYEOF'
import json, os, subprocess
out = os.environ["SC_OUT"]
side = out[:-4] + ".json" if out.endswith(".mp4") else out + ".json"
def iint(v):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None
try:
    probed = float(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", out],
        text=True).strip())
except Exception:
    probed = 0.0
try:
    size = os.path.getsize(out)
except OSError:
    size = 0
e2e = float(os.environ["SC_E2E"] or 0)
steps = int(os.environ["SC_STEPS"])
dur = float(os.environ["SC_DUR"])
doc = {
    "file": os.path.basename(out),
    "created_at_utc": os.environ["SC_DATE"],
    "environment": {
        "host": os.environ["SC_HOST"],
        "gpu": os.environ["SC_GPU"],
        "git_rev": os.environ["SC_GIT"],
        "server_url": os.environ["SC_URL"],
        "server_model": os.environ["SC_MODEL"],
        "script_profile": os.environ["SC_PROFILE"],
    },
    "method": {
        "endpoint": "POST /v1/videos/sync",
        "mode": os.environ["SC_MODE"],
        "task": os.environ["SC_TASK"],
        "params": {
            "width": 960, "height": 576, "fps": 24,
            "num_inference_steps": steps, "flow_shift": 12,
            "seed": int(os.environ["SC_SEED"]),
            "duration": dur, "audio_flow_shift": 3.0,
        },
        "prompt": os.environ["SC_PROMPT"],
    },
    "speed": {
        "e2e_s": round(e2e, 3),
        "video_dur_s": round(probed, 3),
        "mp4_bytes": size,
        "sec_per_step": round(e2e / steps, 3) if steps else 0,
        "realtime_factor": round(e2e / dur, 2) if dur else 0,
    },
    "resources": {
        "memory_before_mb": {"used": iint(os.environ["SC_MEM_BU"]),
                             "available": iint(os.environ["SC_MEM_BA"])},
        "memory_after_mb": {"used": iint(os.environ["SC_MEM_AU"]),
                            "available": iint(os.environ["SC_MEM_AA"])},
        "swap_used_before_mb": iint(os.environ["SC_SWAP_B"]),
        "swap_used_after_mb": iint(os.environ["SC_SWAP_A"]),
        "gpu_temp_c": {"before": iint(os.environ["SC_GPU_TB"]),
                       "after": iint(os.environ["SC_GPU_TA"])},
    },
}
with open(side, "w") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
print(f"sidecar: {side}")
PYEOF
}

n=0
# 공통 미러: results/ 산출물을 NAS Secondary로 복사 (NAS 없으면 조용히 무시).
MIRROR_LIB="$(cd "$BASEDIR/../../../.." && pwd)/mirror-results.sh"
[ -f "$MIRROR_LIB" ] && . "$MIRROR_LIB" || true
command -v mirror_results >/dev/null 2>&1 || mirror_results() { :; }
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
    read -r MEM_BU MEM_BA MEM_SWAP_B <<<"$(mem_snapshot)"; GPU_TB="$(gpu_temp)"
    if [ "$MODE" = "chain" ] && [ "$n" -gt 1 ] && [ -f "$FRAME" ]; then
      TASK="ref2va"
      E2E=$(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
        --max-time 14400 \
        -F "input_reference=@${FRAME};type=image/jpeg" \
        -F "prompt=${prompt}" \
        -F 'width=960' -F 'height=576' -F 'fps=24' \
        -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F "seed=$seed" \
        -F "extra_params={\"task\":\"ref2va\",\"duration\":$DUR,\"audio_flow_shift\":3.0}" \
        -o "$out" -w '%{time_total}')
    else
      TASK="t2va"
      E2E=$(set -x; curl --fail-with-body -sS -X POST "http://127.0.0.1:$H3_PORT/v1/videos/sync" \
        -F "prompt=${prompt}" \
        -F 'width=960' -F 'height=576' -F 'aspect_ratio=16:9' \
        -F 'fps=24' -F "num_inference_steps=$STEPS" -F 'flow_shift=12' -F "seed=$seed" \
        -F "extra_params={\"task\":\"t2va\",\"duration\":$DUR,\"audio_flow_shift\":3.0}" \
        --max-time 7200 -o "$out" -w '%{time_total}')
    fi
    echo "$n,$id,$STEPS,$DUR,$E2E" >> "$TIMINGS"
    ls -lh "$out"
    read -r MEM_AU MEM_AA MEM_SWAP_A <<<"$(mem_snapshot)"; GPU_TA="$(gpu_temp)"
    write_sidecar "$out" "$TASK" "$E2E" "$prompt" "$seed"
    mirror_results
  fi
  dur_ok "$out" || { echo "FAIL: 길이 이상: $out"; exit 1; }
  if [ "$MODE" = "chain" ]; then
    (set -x; ffmpeg -v error -y -sseof -3 -i "$out" -frames:v 1 "$FRAME")
  fi
done

echo "== 합산 검증 =="
mirror_results  # 최종 미러 (샷별 미러 누락분 대비)
TOTAL=$(for f in "$OUTDIR"/*.mp4; do
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f"
done | awk '{s+=$1} END{printf "%.1f", s}')
EXPECT=$((${#SHOTS[@]} * DUR))
echo "shots: ${#SHOTS[@]}, total: ${TOTAL}s (expect ~${EXPECT}s)"
echo "timings: $TIMINGS"
echo
echo "다음: video/showcase/assemble.sh \"$OUTDIR\" \"$BASEDIR/matchgirl.mp4\"  (리포 루트에서 실행)"
