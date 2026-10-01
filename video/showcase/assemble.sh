#!/usr/bin/env bash
# assemble.sh: 샷들을 concat → 본편 (showcase 공용).
# 동일 코덱 전제라 -c copy (재인코딩 없음). 샷 부족 시 WARN 후 있는 만큼 조립.
#   ./assemble.sh                  # 기본: matchgirl/shots → matchgirl/matchgirl_5min.mp4
#   ./assemble.sh INDIR [OUT]      # 다른 showcase 재사용 (EXPECT/EXPECT_SHOTS env로 조정)
set -euo pipefail

BASEDIR="$(dirname "$0")"
# 양산 결과는 /rosenas/data/AIML/comfyui/results/<slug>/ 에 저장 (빈값이면 로컬).
RESULTS_ROOT="${RESULTS_ROOT-/rosenas/data/AIML/comfyui/results}"
if [ -n "$RESULTS_ROOT" ]; then DIN="$RESULTS_ROOT/matchgirl/shots"; DOUT="$RESULTS_ROOT/matchgirl/matchgirl_5min.mp4";
else DIN="$BASEDIR/matchgirl/shots"; DOUT="$BASEDIR/matchgirl/matchgirl_5min.mp4"; fi
INDIR="${1:-$DIN}"
OUT="${2:-$DOUT}"
EXPECT="${EXPECT:-300}"
EXPECT_SHOTS="${EXPECT_SHOTS:-20}"
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
(set -x; ffmpeg -v error -y -f concat -safe 0 -i "$LIST" \
  -c copy -movflags +faststart "$OUT")

echo "== 검증 =="
ls -lh "$OUT"
ffprobe -v error -show_entries stream=index,codec_name,width,height,r_frame_rate,sample_rate,channels \
  -of default=noprint_wrappers=1 "$OUT"
GOT=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$OUT")
echo "duration: ${GOT}s (expect ~${EXPECT}s)"
awk -v g="$GOT" -v e="$EXPECT" 'BEGIN{exit !(g>=e-10 && g<=e+10)}' \
  && echo "OK: $OUT" \
  || { echo "WARN: 기대 길이와 오차 (샷 누락/단축판 가능)"; exit 1; }
