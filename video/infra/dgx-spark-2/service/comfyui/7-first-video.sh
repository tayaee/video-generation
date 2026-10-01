#!/usr/bin/env bash
# 7-first-video: 첫 영상 뽑기. 실행 순서 7/9.
#   ./7-first-video.sh [workflow.json]   (없으면 H3 노드 확인 + 수동 가이드 출력)
# workflow.json은 ComfyUI에서 "Save (API Format)"으로 뽑은 파일.
# 자동 모드: /prompt 큐잉 -> /history 폴링 -> mp4/wav 다운로드.
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
DATA_ROOT="${DATA_ROOT:-$HOME/data/minimax-h3-comfyui}"
WF="${1:-}"
TIMEOUT="${GEN_TIMEOUT:-3600}"

curl -s -m 5 "http://127.0.0.1:8188/system_stats" >/dev/null \
  || { echo "FAIL: ComfyUI 없음. ./5-up.sh 먼저"; exit 1; }

echo "== H3 네이티브 노드 확인 =="
NODES=$(curl -s -m 30 "http://127.0.0.1:8188/object_info" | grep -oi "minimaxh3[a-z]*" | sort -u || true)
echo "${NODES:-'(minimax 노드 없음!)'}"
echo "$NODES" | grep -qi "minimaxh3imagetovideo" || echo "WARN: MiniMaxH3ImageToVideo 미등록 (버전 확인: 0.30+)"

if [ -z "$WF" ]; then
  cat <<'EOF'

수동 가이드 (workflow.json 없이 바로 뽑기):
  1) http://<spark>:8188 접속 (SSH 터널)
  2) 좌측 Template Library -> Video -> "MiniMax H3 T2V" 로드
  3) Resolution: 864x480부터 (608x352=스모크, 1344x768=네이티브)
  4) 프롬프트는 장면+카메라+오디오(대사/SFX/음악)를 한 블록으로:
     예) Close-up of a street vendor in a neon-lit Seoul alley on a rainy night,
         he looks at the camera and says fresh hotteok two for a dollar,
         sizzling grill sounds, rain patter, distant traffic hum.
  5) Queue -> output은 $DATA_ROOT/output
  6) API 자동화하려면 Canvas 메뉴 "Save (API Format)"으로 json 저장 후:
     ./7-first-video.sh my_t2v_api.json

권장 베이스: steps=20, cfg=1.0, sampler=euler, scheduler=simple
EOF
  echo "다음(정리): ./8-stop.sh"
  exit 0
fi

[ -f "$WF" ] || { echo "FAIL: workflow 없음: $WF"; exit 1; }
echo "== 큐잉: $WF =="
MARKER="$DATA_ROOT/.gen_start"
touch "$MARKER"
PID=$(set -x; curl -s -m 30 -X POST "http://127.0.0.1:8188/prompt" \
  -H 'Content-Type: application/json' \
  -d "{\"prompt\": $(cat "$WF")}" | python3 -c "import sys,json; print(json.load(sys.stdin)['prompt_id'])")
echo "prompt_id=$PID"

echo "== 완료 대기 (최대 ${TIMEOUT}s) =="
START=$(date +%s)
while true; do
  STATUS=$(curl -s -m 15 "http://127.0.0.1:8188/history/$PID")
  echo "$STATUS" | grep -q '"status"' && echo "$STATUS" | python3 -c "
import sys,json
h=json.load(sys.stdin)['$PID']
print('status:', h.get('status',{}).get('status_str'), '| done:', h.get('status',{}).get('completed'))" || true
  DONE=$(echo "$STATUS" | python3 -c "
import sys,json
try: print(json.load(sys.stdin)['$PID']['status']['completed'])
except Exception: print('False')")
  [ "$DONE" = "True" ] && break
  NOW=$(date +%s)
  [ $((NOW-START)) -gt "$TIMEOUT" ] && { echo "FAIL: 생성 타임아웃"; exit 1; }
  sleep 20
done

echo "== 산출물 ($DATA_ROOT/output) =="
ls -lht "$DATA_ROOT/output" | head -10
# 양산 결과는 /rosenas/data/AIML/video-generation/results/<slug>/ 에 저장 (빈값이면 복사 생략).
RESULTS_ROOT="${RESULTS_ROOT-/rosenas/data/AIML/video-generation/results}"
if [ -n "$RESULTS_ROOT" ]; then
  SLUG="${SLUG:-$(basename "$WF" .json)}"
  DEST="$RESULTS_ROOT/$SLUG"
  mkdir -p "$DEST"
  [ -w "$DEST" ] || { echo "FAIL: 쓰기 불가: $DEST"; exit 1; }
  if [ -n "$(find "$DATA_ROOT/output" -type f -newer "$MARKER" -print -quit)" ]; then
    (set -x; find "$DATA_ROOT/output" -type f -newer "$MARKER" -exec cp -t "$DEST" {} +)
    echo "results: $DEST"
  else
    echo "WARN: 신규 산출물 없음 (복사 생략)"
  fi
  rm -f "$MARKER"
fi
echo
echo "다음(정리): ./8-stop.sh"
