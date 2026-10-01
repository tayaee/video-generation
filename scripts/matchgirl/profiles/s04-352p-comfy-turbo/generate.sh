#!/usr/bin/env bash
# scripts/matchgirl/profiles/s04-352p-comfy-turbo/generate.sh: 초고속 previz (36샷 x 5s = 180s, STEPS=4).
# spark1에서 실행, spark2 ComfyUI(turbo_8step LoRA)에 API 큐잉.
# 실험적: 8step용 LoRA를 4스텝으로 돌리는 off-contract 구성이라 품질 보장 없음.
# 이야기 리듬 확인용으로만 사용. 화면 확인용은 s08 이상 권장.
#   ./generate.sh                  # 36샷 previz
#   LIST=1 ./generate.sh           # 샷 목록만 출력
#   COUNT=1 ./generate.sh          # smoke
set -euo pipefail

COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"  # spark1 프록시 경유. 직통은 http://192.168.102.2:8188
STEPS="${STEPS:-4}"                               # 실험값 (8step LoRA off-contract)
DUR="${DUR:-5}"
RES="${RES:-608x352}"                            # 검증됨. 864x480은 spark2 메모리 확인 후
LIST="${LIST:-0}"
COUNT="${COUNT:-0}"
GEN_TIMEOUT="${GEN_TIMEOUT:-3600}"
BASEDIR="$(dirname "$0")"
REPO_ROOT="$(cd "$BASEDIR/../../../.." && pwd)"
# 산출물은 프로파일 디렉토리 안 shots/ (리포 Primary, NAS는 sync-results.sh로 복사).
OUTDIR="${OUTDIR:-$REPO_ROOT/results/matchgirl/profiles/s04-352p-comfy-turbo/shots}"
TIMINGS="$OUTDIR/timings.csv"
# 워크플로우 템플릿 (API Format). 주입점: 15=프롬프트·해상도·길이, 19=시드, 24=파일명.
TEMPLATE="${TEMPLATE:-$REPO_ROOT/scripts/showcase/t2v_first.json}"

GIRL="a barefoot girl of about nine with reddish-gold hair under a patched gray coat, clutching a bundle of matchboxes"
# 장소 바이블 (같은 장면 고정용, verbatim 유지. 인물 바이블과 동일 기법).
ATTIC="the same small attic room at dawn, frost on the inside of the window"
STREET="the same snow-covered cobblestone street at New Year Eve dusk, warm windows glowing across the street"
ALLEY="the same narrow alley corner between two dark brick houses at night, snow piled against the walls, a single dim street lamp glowing"
DAWN_STREET="the same cobblestone street at cold blue dawn, thin snow over everything, pale morning light"
# 시간 앵커 (같은 장면 내 연속 표시).
SAME_EVE="the same evening, moments later"
SAME_NIGHT="the same night, moments later"
SAME_DAWN="the same cold dawn, moments later"

SHOTS=(
# ── 막1: 새해 전날 (아침 출발 → 해질녘 거리) ──
"01_morning_attic|Photorealistic ${ATTIC}. ${GIRL} wraps a thin shawl, tucks the match bundle inside her coat, and steps out into the cold morning. Slow pull-back. Floorboard creaks, thin blanket rustle, distant rooster, cold wind under the door."
"02_lost_slippers|Photorealistic snowy morning street, two carriages thunder past. ${GIRL} stumbles in oversized slippers, one flies off and a running boy snatches it up laughing, gone around the corner. Handheld panic. Horse hooves, wheel rattle, boy laughter fading, her small cry in Korean, 내 신발!"
"03_dusk_street|Photorealistic period film, ${STREET}, snow falling. ${GIRL} holds up her matches to hurrying passersby and calls out in Korean, 성냥 사세요, breath fogging. Slow dolly-in. Faint Korean street cry, wind howl, distant church bells, crunching snow under boots."
"04_barefoot_snow|Photorealistic close-up on ${STREET}, ${SAME_EVE}, small bare feet stepping into fresh snow, toes red with cold. ${GIRL} hurries past shuttered shops. Handheld follow. Snow crunch, ragged breathing, a far-off children's choir rehearsing a carol in Korean, wind gusts."
"05_unsold_matches|Photorealistic street level on ${STREET}, ${SAME_EVE}, frost-covered bundle of matchboxes in small hands. ${GIRL} holds them up to hurrying passersby legs, no one stops. Static then slight tilt down. Muffled footsteps fading, coins clinking elsewhere, sighing wind."
"06_rich_family|Photorealistic on ${STREET}, ${SAME_EVE}, a wealthy family in furs hurries past with parcels and a toy horse. ${GIRL} reaches out her matches, the mother pulls her child away without a glance. Slow motion pass. Muffled rich laughter, sleigh bells, her whisper in Korean, 하나만 사주세요."
"07_window_feast|Photorealistic warm restaurant window on ${STREET}, ${SAME_EVE}, diners silhouetted around a feast. ${GIRL} watches from the snowy dark outside, nose near glass. Slow push-in. Muffled laughter and clinking cutlery behind glass, cold wind outside."
# ── 막2: 첫 성냥 · 난로 ──
"08_no_home|Photorealistic, ${GIRL} looks back toward the lit street, then shakes her head and crouches in ${ALLEY}, afraid of her father's switch with no money earned. Trembling close-up. Her chattering whisper in Korean, 빈손으론 못 돌아가, snow hissing on stone."
"09_first_strike|Photorealistic ${ALLEY}, ${SAME_NIGHT}, ${GIRL} crouches and strikes a match against the wall. Sudden flare blooms across her face. Macro of the flame catching. Sharp hiss, held breath, then soft crackle, wind dropping away."
"10_stove_vision|Photorealistic dream vision, a great iron stove glowing with brass ornaments, radiant heat waves. ${GIRL} stretches frozen hands toward it, smiling. Slow orbit. Deep fire crackle, metallic ticks, warm low hum."
"11_warm_hands|Photorealistic close-up inside the vision, her small red hands open before the glowing stove grate, frost melting off her fingertips into steam. ${GIRL} sighs with relief. Extreme macro. Steam hiss, soft relieved sigh in Korean, 따뜻해."
"12_vision_dies|Photorealistic, ${SAME_NIGHT}, the stove vision gutters and dissolves back into ${ALLEY}. ${GIRL} stares at the dead match, smile fading. Match cut to wide. Flame sputter, cold wind rushing back, faint whimper."
"13_cold_returns|Photorealistic, ${SAME_NIGHT}, ${GIRL} shivering hard in ${ALLEY}, wrapping the coat tighter, teeth chattering, deciding on a second match. Trembling close-up. Chattering teeth, shuddering breaths, snow hissing on stone."
# ── 막3: 두 번째 · 거위 ──
"14_second_strike|Photorealistic ${ALLEY}, ${SAME_NIGHT}, a second match flares against the brick, brighter, lighting falling snowflakes like sparks. ${GIRL} gasps. Slow motion flare. Strike scrape, whoosh of flame, tiny awed gasp."
"15_goose_vision|Photorealistic dream vision, a roast goose steaming on a white tablecloth, stuffing and apples, carving knife gleaming. ${GIRL} leans in wide-eyed. Push-in. Rich sizzle, clink of the knife, warm room tone."
"16_goose_rises|Photorealistic dream logic, the roast goose rises with knife and fork in its breast and waddles toward the poor child. ${GIRL} laughs in delight. Gentle tracking. Playful sizzle, soft child laughter, music-box notes."
"17_almost_taste|Photorealistic, ${GIRL} reaches both hands for the waddling goose, mouth open, and the vision bursts like a soap bubble into cold sparks. Her smile freezes. Rack focus. Bubble pop, cold rush, tiny disappointed cry."
"18_dark_again|Photorealistic, the vision snaps to ${ALLEY}, ${SAME_NIGHT}, snow falling harder. ${GIRL} alone again under the street lamp. Crane up. Cutoff of music, heavy snowfall hush, distant midnight bells."
"19_blizzard|Photorealistic whiteout gust through ${ALLEY}, ${SAME_NIGHT}, ${GIRL} staggers, shields the bundle inside her coat, snow plastering her reddish-gold hair. Low angle struggle. Blizzard roar, coat flapping, her strained breath."
"20_last_matches|Photorealistic close-up in ${ALLEY}, ${SAME_NIGHT}, ${GIRL} opens the bundle with numb fingers and counts the last matches, three left, frost on the box labels. Shallow focus. Cardboard rub, finger tremble foley, wind underneath."
# ── 막4: 세 번째 · 트리 ──
"21_third_strike|Photorealistic ${ALLEY}, ${SAME_NIGHT}, a third match bursts into a tall steady flame cupped in both hands. ${GIRL} face glowing amber. Low angle. Strong flare-up, cupped-hands warmth tone, snow sizzling."
"22_tree_vision|Photorealistic dream vision, a towering Christmas tree covered in lit candles and painted ornaments. ${GIRL} reaches up in wonder. Slow tilt up. Soft Korean choir, candle sizzle, ornament glass chimes."
"23_ornaments|Photorealistic inside the vision, glass ornaments reflect her wondering face a hundredfold as ${GIRL} touches one gently and it rings. Slow drift. Glass chime, her delighted whisper in Korean, 예쁘다."
"24_candles_rise|Photorealistic, the tree candles detach and rise into the night sky as stars. ${GIRL} watches, mouth open. Tilt to sky. Korean choir swelling, rising shimmer tone, wind fading to silence."
"25_falling_star|Photorealistic night sky, one star detaches and falls. ${GIRL} whispers to the dark in Korean, 오늘 밤 누군가 죽어. Extreme close-up on eyes. Hushed Korean whisper, long reverb tail, total stillness."
"26_grandmother_memory|Photorealistic warm flashback, her beloved grandmother lifts the laughing child onto her lap by a fireplace, the only face that ever loved her. ${GIRL} as a small child giggles. Soft slow motion. Fireplace crackle, kind humming, child giggle."
"27_bundle_decision|Photorealistic back in ${ALLEY}, ${SAME_NIGHT}, ${GIRL} looks at the last matches, then at the sky where the star fell, and presses the whole bundle together with sudden resolve. Close-up on eyes. Heartbeat rising, matchbox shake, resolve breath."
# ── 막5: 마지막 다발 · 할머니 · 새해 아침 ──
"28_bundle_blaze|Photorealistic, ${GIRL} strikes the whole bundle at once, a bright roaring blaze lighting ${ALLEY} like noon. Wide shot. Roaring flare, crackling storm of matches, heartbeat drum."
"29_grandmother|Photorealistic radiant vision, her grandmother appears in warm light, arms open, kindest face, murmuring in Korean, 이제 따뜻할 거야. ${GIRL} runs into the embrace. Slow motion. Soft Korean murmur and humming lullaby, warmest room tone, faint Korean choir."
"30_embrace|Photorealistic inside the blaze, the grandmother wraps ${GIRL} in her shawl, the child sobbing with joy, snowflakes turning to sparks around them. Slow orbit. Shawl fabric, joyful sobs, choir warming."
"31_ascent|Photorealistic ascent above snowy rooftops, the grandmother carrying ${GIRL} upward, town shrinking below, snowflakes hanging still. Crane soaring. Korean choir and heartbeat slowing together, then quiet."
"32_among_stars|Photorealistic, the grandmother and ${GIRL} drift among gentle stars, the child asleep on her shoulder, utterly at peace. Weightless drift. Choir dissolving to silence, one soft bell."
"33_dawn_alley|Photorealistic cold dawn, ${ALLEY} lies empty and blue, thin snow over everything. ${GIRL} leans against the wall under thin snow, still, the burnt bundle beside her. Slow descent from sky to street. Dawn wind, far-off cock crow, emptiness."
"34_dawn_smile|Photorealistic dawn close-up in ${ALLEY}, ${SAME_DAWN}, her small face with a peaceful smile, cheeks rosy, one burnt match still between her fingers. ${GIRL} rests forever warm in the vision. Static reverent close-up. Morning stillness, faint thaw drip."
"35_found_bells|Photorealistic, ${SAME_DAWN}, morning passersby gather and kneel around her in ${ALLEY}, a woman covers her with a shawl, church bells ring the New Year. ${GIRL} is found smiling. Rising crane. Church bells, murmuring crowd, a woman's soft sob in Korean, 불쌍해서 어째."
"36_new_year|Photorealistic New Year morning wide on ${DAWN_STREET}, ${SAME_DAWN}, sun breaks over snowy rooftops, children run laughing with new toys past the quiet alley, light blooming over the town. Slow pull-back to sky. Children laughter, morning bells, birdsong, thaw dripping into the new year."
)

# COUNT>0이면 앞 N샷만 (smoke용). LIST·EXPECT·resume 로직이 자동 추종.
[ "${COUNT:-0}" -gt 0 ] 2>/dev/null && SHOTS=("${SHOTS[@]:0:$COUNT}") || true

W="${RES%x*}"; H="${RES#*x}"
LENGTH=$((DUR * 24 + 4))  # 5s → 124프레임 (t2v_first 검증값)

dur_ok() { # file
  local got
  got=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null || echo 0)
  awk -v d="$got" -v e="$DUR" 'BEGIN{exit !(d>=e-2 && d<=e+15)}'
}

mem_snapshot() { # "used_MB available_MB swap_used_MB" 출력 (클라이언트 기준)
  awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2} \
    END{printf "%d %d %d", (t-a)/1024, a/1024, (st-sf)/1024}' /proc/meminfo 2>/dev/null || echo "0 0 0"
}

gpu_temp() { # GPU 온도(℃) 출력, 실패 시 unknown
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1 | tr -d ' \n' || echo unknown
}

# 템플릿 노드 검증 (주입점 15/19/24). LIST 모드에서도 수행.
TEMPLATE_OK="$(TEMPLATE="$TEMPLATE" python3 - <<'PYEOF' 2>&1 || echo "TEMPLATE_FAIL"
import json, os, sys
try:
    d = json.load(open(os.environ["TEMPLATE"]))
    assert d["15"]["class_type"] == "MiniMaxH3ImageToVideo", "node 15 class mismatch"
    assert d["19"]["class_type"] == "RandomNoise", "node 19 class mismatch"
    assert d["24"]["class_type"] == "SaveVideo", "node 24 class mismatch"
    print("TEMPLATE_OK")
except Exception as e:
    print(f"TEMPLATE_FAIL: {e}")
PYEOF
)"
echo "$TEMPLATE_OK" | grep -q "^TEMPLATE_OK$" \
  || { echo "FAIL: 워크플로우 템플릿 이상: $TEMPLATE ($TEMPLATE_OK)"; exit 1; }

if [ "$LIST" = "1" ]; then
  echo "outdir: $OUTDIR"
  echo "comfy: $COMFY_URL, template: $TEMPLATE, res: ${W}x${H}, length: $LENGTH"
  n=0
  for entry in "${SHOTS[@]}"; do
    n=$((n+1)); printf '%02d %s (%ss)\n' "$n" "${entry%%|*}" "$DUR"
  done
  echo "total: $n shots x ${DUR}s = $((n * DUR))s (turbo steps=$STEPS)"
  exit 0
fi

curl -s -m 5 "$COMFY_URL/system_stats" >/dev/null \
  || { echo "FAIL: ComfyUI 없음 ($COMFY_URL). spark2 5-up.sh + spark1 proxy-up.sh 확인"; exit 1; }
mkdir -p "$OUTDIR"
[ -f "$BASEDIR/profile.json" ] && cp "$BASEDIR/profile.json" "$(dirname "$OUTDIR")/profile.json" 2>/dev/null || true  # 설명 results 미러 (NAS 수집용)
[ -w "$OUTDIR" ] || { echo "FAIL: 쓰기 불가: $OUTDIR"; exit 1; }
[ -f "$TIMINGS" ] || echo "shot,id,steps,dur_s,e2e_s" > "$TIMINGS"

# 공통 미러: results/ 산출물을 NAS Secondary로 복사 (NAS 없으면 조용히 무시).
MIRROR_LIB="$REPO_ROOT/scripts/common/mirror-results.sh"
[ -f "$MIRROR_LIB" ] && . "$MIRROR_LIB" || true
command -v mirror_results >/dev/null 2>&1 || mirror_results() { :; }

queue_shot() { # id prompt seed stem → stdout: prompt_id (stderr: 로그)
  local id="$1" prompt="$2" seed="$3" stem="$4"
  local wf
  wf="$(mktemp)"
  TEMPLATE="$TEMPLATE" WF_OUT="$wf" Q_PROMPT="$prompt" Q_SEED="$seed" \
  Q_W="$W" Q_H="$H" Q_LEN="$LENGTH" Q_STEPS="$STEPS" Q_STEM="$stem" python3 - <<'PYEOF'
import json, os
d = json.load(open(os.environ["TEMPLATE"]))
d["15"]["inputs"]["prompt"] = os.environ["Q_PROMPT"]
d["15"]["inputs"]["width"] = int(os.environ["Q_W"])
d["15"]["inputs"]["height"] = int(os.environ["Q_H"])
d["15"]["inputs"]["length"] = int(os.environ["Q_LEN"])
d["18"]["inputs"]["steps"] = int(os.environ["Q_STEPS"])
d["19"]["inputs"]["noise_seed"] = int(os.environ["Q_SEED"])
d["24"]["inputs"]["filename_prefix"] = "matchgirl/s04-turbo/" + os.environ["Q_STEM"]
json.dump(d, open(os.environ["WF_OUT"], "w"))
PYEOF
  (set -x; curl -sS -m 30 -X POST "$COMFY_URL/prompt" \
    -H 'Content-Type: application/json' \
    -d "{\"prompt\": $(cat "$wf")}") | python3 -c "import sys,json; print(json.load(sys.stdin)['prompt_id'])"
  rm -f "$wf"
}

wait_shot() { # prompt_id → stdout: 완료 시각(초). 실패 시 exit 1
  local pid="$1" start now st
  start=$(date +%s)
  while true; do
    st="$(curl -s -m 15 "$COMFY_URL/history/$pid" 2>/dev/null || echo '{}')"
    if echo "$st" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('$pid',{}).get('status',{}).get('completed') else 1)" 2>/dev/null; then
      date +%s; return 0
    fi
    if echo "$st" | grep -q '"status_str": *"error"'; then
      echo "FAIL: ComfyUI 에러: $st" >&2; return 1
    fi
    now=$(date +%s)
    [ $((now - start)) -gt "$GEN_TIMEOUT" ] && { echo "FAIL: 생성 타임아웃 (${GEN_TIMEOUT}s)" >&2; return 1; }
    sleep 20
  done
}

fetch_mp4() { # prompt_id out — history에서 mp4 찾아 /view로 다운로드
  local pid="$1" out="$2"
  PID="$pid" OUT="$out" URL="$COMFY_URL" python3 - <<'PYEOF'
import json, os, urllib.request
pid, url, out = os.environ["PID"], os.environ["URL"], os.environ["OUT"]
h = json.load(urllib.request.urlopen(f"{url}/history/{pid}", timeout=30))[pid]
cands = []
for node_out in h.get("outputs", {}).values():
    for key in ("gifs", "videos", "images"):
        for f in node_out.get(key, []):
            if f.get("filename", "").endswith((".mp4", ".wav")):
                cands.append(f)
mp4s = [c for c in cands if c["filename"].endswith(".mp4")] or cands
if not mp4s:
    raise SystemExit(f"FAIL: 산출물 없음: {json.dumps(h.get('outputs', {}))[:300]}")
f = mp4s[0]
q = f"filename={urllib.parse.quote(f['filename'])}&subfolder={urllib.parse.quote(f.get('subfolder',''))}&type={urllib.parse.quote(f.get('type','output'))}"
urllib.request.urlretrieve(f"{url}/view?{q}", out)
print(f"fetched: {out}")
PYEOF
}

write_sidecar() { # out e2e prompt seed t0 t1 — 생성 직후 <stem>.json 기록
  local out="$1" e2e="$2" prompt="$3" seed="$4" t0="$5" t1="$6"
  SC_OUT="$out" SC_E2E="$e2e" SC_PROMPT="$prompt" SC_SEED="$seed" \
  SC_URL="$COMFY_URL" SC_MODE="turbo" SC_PROFILE="s04-352p-comfy-turbo" \
  SC_STEPS="$STEPS" SC_DUR="$DUR" SC_W="$W" SC_H="$H" SC_LEN="$LENGTH" \
  SC_HOST="$(hostname 2>/dev/null || echo unknown)" \
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
        "server_url": os.environ["SC_URL"],
        "server": "spark2 ComfyUI (turbo_8step LoRA)",
        "script_profile": os.environ["SC_PROFILE"],
        "note": "memory는 spark1 클라이언트 기준. 생성 부하는 spark2",
    },
    "method": {
        "endpoint": "POST /prompt (ComfyUI API)",
        "mode": os.environ["SC_MODE"],
        "task": "t2v-turbo",
        "params": {
            "width": int(os.environ["SC_W"]), "height": int(os.environ["SC_H"]),
            "length_frames": int(os.environ["SC_LEN"]),
            "steps": steps, "seed": int(os.environ["SC_SEED"]),
            "duration": dur,
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
        "note": "memory·온도는 spark1 클라이언트 기준. 생성 부하는 spark2",
    },
}
with open(side, "w") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
print(f"sidecar: {side}")
PYEOF
}

n=0
for entry in "${SHOTS[@]}"; do
  n=$((n+1))
  id="${entry%%|*}"
  prompt="${entry#*|}"
  stem="$(printf '%02d' "$n")_${id#[0-9][0-9]_}_s04"
  out="$OUTDIR/$stem.mp4"
  seed=$((1101 + n))
  if [ -f "$out" ] && dur_ok "$out"; then
    echo "===== [$n/${#SHOTS[@]}] $id: skip exists ====="
  else
    echo "===== [$n/${#SHOTS[@]}] $id (${DUR}s, turbo steps=$STEPS, res=${W}x${H}) ====="
    read -r MEM_BU MEM_BA MEM_SWAP_B <<<"$(mem_snapshot)"; GPU_TB="$(gpu_temp)"
    T0=$(date +%s)
    PID="$(queue_shot "$id" "$prompt" "$seed" "$stem")"
    echo "prompt_id=$PID"
    T1="$(wait_shot "$PID")"
    E2E=$((T1 - T0))
    fetch_mp4 "$PID" "$out"
    echo "$n,$id,$STEPS,$DUR,$E2E" >> "$TIMINGS"
    ls -lh "$out"
    read -r MEM_AU MEM_AA MEM_SWAP_A <<<"$(mem_snapshot)"; GPU_TA="$(gpu_temp)"
    write_sidecar "$out" "$E2E" "$prompt" "$seed" "$T0" "$T1"
    mirror_results
  fi
  dur_ok "$out" || { echo "FAIL: 길이 이상: $out"; exit 1; }
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
echo "다음: scripts/common/assemble.sh \"$OUTDIR\" \"$REPO_ROOT/results/matchgirl/profiles/s04-352p-comfy-turbo/matchgirl_turbo.mp4\"  (리포 루트에서 실행)"
