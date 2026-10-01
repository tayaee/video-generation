#!/usr/bin/env bash
# docs/serve.sh: 갤러리 서빙 (A 방식: Codespace 로컬 파일).
#   ./docs/serve.sh                 # 03번샷 pull + manifest + :8001 서빙
#   SHOTS=03,04 ./docs/serve.sh     # 추가 샷 포함
#   PORT=8001 ./docs/serve.sh
# Codespace는 리포 루트에서 :8001을 서빙. sleep/wake에 파일 유지, 재생성시에만 pull.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOTS="${SHOTS:-03}"
PORT="${PORT:-8001}"
cd "$REPO"

echo "== LFS pull (shots: $SHOTS) =="
IFS=',' read -ra NS <<<"$SHOTS"
PAT=""
for n in "${NS[@]}"; do
  [ -n "$PAT" ] && PAT="$PAT,"
  PAT="${PAT}results/matchgirl/profiles/*/shots/${n}_*"
done
(git lfs pull -I "$PAT" 2>&1 || echo "(lfs pull 스킵/불필요)") | head -n 5 || true

echo "== manifest =="
SHOTS="$SHOTS" WORK=matchgirl ./scripts/common/gen-manifest.sh

echo "== serve :$PORT (root=$REPO) =="
echo "open: http://localhost:$PORT/docs/ (codespace면 forwarded URL + /docs/)"
exec python3 -m http.server "$PORT" --bind 0.0.0.0
