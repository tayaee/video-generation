#!/usr/bin/env bash
# 2-prepare-source: ComfyUI 소스 확보 (H3 네이티브는 0.30+). 실행 순서 2/9.
# canonical read-only clone인 ~/git/ComfyUI에서 COMM_TAG(기본 v0.30.0)를
# git archive로 뽑아 ./comfyui-src에 materialize한다.
# docker build 컨텍스트 안에 소스가 있어야 해서 copy 방식이며,
# ./comfyui-src는 빌드 산출물이라 git 추적 안 함 (.gitignore) — nested repo 금지.
# ~/git/ComfyUI에는 직접 손대지 말 것 (fetch만, commit/push 금지).
# 태그 교체는 COMM_TAG=<tag> ./2-prepare-source.sh 로 재실행하면 자동 갱신된다.
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
COMM_TAG="${COMM_TAG:-v0.30.0}"
REF="${COMFYUI_REF:-$HOME/git/ComfyUI}"
SRC="$BASEDIR/comfyui-src"

if [ ! -d "$REF/.git" ]; then
  echo "== canonical clone 없음, 새로 받음: $REF =="
  (set -x; git clone https://github.com/comfyanonymous/ComfyUI.git "$REF")
fi
(set -x; git -C "$REF" fetch --tags --quiet 2>/dev/null) || true
git -C "$REF" cat-file -e "$COMM_TAG^{commit}" 2>/dev/null \
  || { echo "FAIL: $REF 에 $COMM_TAG 없음 (git -C $REF fetch --tags 후 재실행)"; exit 1; }

PIN="$(git -C "$REF" rev-parse "$COMM_TAG^{commit}")"
if [ -f "$SRC/main.py" ] && [ -f "$SRC/.comfyui-pin" ] && [ "$(cat "$SRC/.comfyui-pin")" = "$PIN" ]; then
  echo "exists: $SRC ($COMM_TAG, ${PIN:0:9})"
else
  echo "== materialize ComfyUI $COMM_TAG (${PIN:0:9}) -> $SRC =="
  rm -rf "$SRC"
  mkdir -p "$SRC"
  (set -x; git -C "$REF" archive "$COMM_TAG" | tar -x -C "$SRC")
  echo "$PIN" > "$SRC/.comfyui-pin"
fi

[ -f "$SRC/main.py" ] && [ -f "$SRC/requirements.txt" ] \
  && echo "OK: main.py + requirements.txt 확인" \
  || { echo "FAIL: 소스 불완전"; exit 1; }

echo
echo "다음: ./3-build.sh"
