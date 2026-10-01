#!/usr/bin/env bash
# sync-results.sh: Primary(results/) -> Secondary NAS incremental 복사.
#   ./sync-results.sh  (NAS_DEST env로 변경 가능)
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$BASEDIR/../../results"
DEST="${NAS_DEST:-/rosenas/data/AIML/video-generation/results}"
[ -d "$SRC" ] || { echo "FAIL: $SRC 없음"; exit 1; }
mkdir -p "$DEST"
[ -w "$DEST" ] || { echo "FAIL: 쓰기 불가: $DEST"; exit 1; }

echo "== rsync $SRC/ -> $DEST/ =="
(set -x; rsync -a "$SRC/" "$DEST/")
echo "OK: secondary synced"
