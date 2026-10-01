#!/usr/bin/env bash
# assemble.sh: 샷들을 concat → 본편 (showcase 공용).
# 동일 코덱 전제라 -c copy (재인코딩 없음). 샷 부족 시 WARN 후 있는 만큼 조립.
#   ./assemble.sh  (기본: results/matchgirl/profiles/preview, SHOWCASE_SLUG/QUALITY_PROFILE로 변경)
#   ./assemble.sh INDIR [OUT]  (위치 직접 지정)
set -euo pipefail

BASEDIR="$(dirname "$0")"
REPO="$(cd "$BASEDIR/../.." && pwd)"
SHOWCASE_SLUG="${SHOWCASE_SLUG:-matchgirl}"
QUALITY_PROFILE="${QUALITY_PROFILE:-s10-576p-vllm-t2va}"
INDIR="${1:-$REPO/results/$SHOWCASE_SLUG/profiles/$QUALITY_PROFILE/shots}"
OUT="${2:-$REPO/results/$SHOWCASE_SLUG/profiles/$QUALITY_PROFILE/$SHOWCASE_SLUG.mp4}"
EXPECT="${EXPECT:-180}"
EXPECT_SHOTS="${EXPECT_SHOTS:-36}"
# 공통 미러: 본편을 NAS Secondary로 복사 (NAS 없으면 조용히 무시).
[ -f "$REPO/scripts/common/mirror-results.sh" ] && . "$REPO/scripts/common/mirror-results.sh" || true
command -v mirror_results >/dev/null 2>&1 || mirror_results() { :; }
LIST="$INDIR/.concat.txt"
mkdir -p "$(dirname "$OUT")"
[ -w "$(dirname "$OUT")" ] || { echo "FAIL: 쓰기 불가: $(dirname "$OUT")"; exit 1; }

mapfile -t CLIPS < <(ls "$INDIR"/*.mp4 2>/dev/null | sort)
[ "${#CLIPS[@]}" -gt 0 ] || { echo "FAIL: mp4 없음: $INDIR (generate.sh 먼저)"; exit 1; }
[ "${#CLIPS[@]}" -eq "$EXPECT_SHOTS" ] \
  || echo "WARN: 샷 ${#CLIPS[@]}/$EXPECT_SHOTS개 — 있는 만큼 조립 (중단됐으면 generate.sh 재실행이 resume)"

: > "$LIST"
for c in "${CLIPS[@]}"; do echo "file '$c'" >> "$LIST"; done

echo "== concat ${#CLIPS[@]} clips -> $OUT =="
ASM_T0=$(date +%s)
(set -x; ffmpeg -v error -y -f concat -safe 0 -i "$LIST" \
  -c copy -movflags +faststart "$OUT")
ASM_T1=$(date +%s)
ASM_E2E=$((ASM_T1 - ASM_T0))

echo "== 검증 =="
ls -lh "$OUT"
mirror_results  # 본편 미러
ffprobe -v error -show_entries stream=index,codec_name,width,height,r_frame_rate,sample_rate,channels \
  -of default=noprint_wrappers=1 "$OUT"
GOT=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$OUT")
echo "duration: ${GOT}s (expect ~${EXPECT}s)"
# 본편 sidecar: 조립 시간 + 샷 시간 합산 + 샷별 e2e (timings.csv).
ASM_OUT="$OUT" ASM_E2E_S="$ASM_E2E" ASM_GOT="$GOT" ASM_INDIR="$INDIR" \
ASM_SLUG="$SHOWCASE_SLUG" ASM_PROF="$QUALITY_PROFILE" ASM_EXPECT="$EXPECT" \
ASM_HOST="$(hostname 2>/dev/null || echo unknown)" \
ASM_GIT="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
ASM_DATE="$(date -u +%FT%TZ)" \
python3 - <<'PYEOF'
import csv, json, os, subprocess
out = os.environ["ASM_OUT"]
side = out[:-4] + ".json" if out.endswith(".mp4") else out + ".json"
clips, total = [], 0.0
for c in sorted(os.listdir(os.environ["ASM_INDIR"])):
    if not c.endswith(".mp4"):
        continue
    try:
        d = float(subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1",
             os.path.join(os.environ["ASM_INDIR"], c)], text=True).strip())
    except Exception:
        d = 0.0
    clips.append({"file": c, "dur_s": round(d, 3)})
    total += d
shots, e2e_sum, steps = [], 0.0, set()
tcsv = os.path.join(os.environ["ASM_INDIR"], "timings.csv")
if os.path.isfile(tcsv):
    with open(tcsv) as f:
        for row in csv.DictReader(f):
            try:
                e = float(row.get("e2e_s") or 0)
            except ValueError:
                e = 0.0
            shots.append({"shot": row.get("shot"), "id": row.get("id"),
                          "steps": row.get("steps"), "dur_s": row.get("dur_s"),
                          "e2e_s": round(e, 3)})
            e2e_sum += e
            if row.get("steps"):
                steps.add(str(row.get("steps")))
try:
    size = os.path.getsize(out)
except OSError:
    size = 0
doc = {
    "file": os.path.basename(out),
    "created_at_utc": os.environ["ASM_DATE"],
    "environment": {
        "host": os.environ["ASM_HOST"],
        "git_rev": os.environ["ASM_GIT"],
        "slug": os.environ["ASM_SLUG"],
        "profile": os.environ["ASM_PROF"],
    },
    "method": {
        "assembly": "ffmpeg concat -c copy (재인코딩 없음)",
        "indir": os.environ["ASM_INDIR"],
        "expect_s": float(os.environ["ASM_EXPECT"]),
    },
    "assembly": {
        "e2e_s": int(os.environ["ASM_E2E_S"]),
        "merged_dur_s": round(float(os.environ["ASM_GOT"] or 0), 3),
        "mp4_bytes": size,
    },
    "shots_time": {
        "clip_count": len(clips),
        "clip_dur_sum_s": round(total, 3),
        "gen_e2e_sum_s": round(e2e_sum, 3),
        "gen_e2e_sum_h": round(e2e_sum / 3600, 2),
        "steps_seen": sorted(steps),
        "per_shot_e2e": shots,
    },
    "clips": clips,
}
with open(side, "w") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
print(f"sidecar: {side} (assembly {os.environ['ASM_E2E_S']}s, shots e2e sum {round(e2e_sum,1)}s)")
PYEOF
awk -v g="$GOT" -v e="$EXPECT" 'BEGIN{exit !(g>=e-10 && g<=e+10)}' \
  && echo "OK: $OUT" \
  || { echo "WARN: 기대 길이와 오차 (샷 누락/단축판 가능)"; exit 1; }
