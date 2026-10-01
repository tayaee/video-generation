#!/usr/bin/env bash
# 2-download: MiniMax-H3 가중치 + vllm-omni 체크아웃. 실행 순서 2/9.
# GB10 1x는 파티션을 하나씩만 상주시키므로 기본 FL2VA만 받는다.
#   ./2-download.sh [FL2VA|Ref2VA|all]   (기본 FL2VA)
set -euo pipefail

PART="${1:-FL2VA}"
H3_ROOT="${H3_ROOT:-$HOME/models/MiniMax-H3}"
HF_REPO="MiniMaxAI/MiniMax-H3"

mkdir -p "$H3_ROOT"

case "$PART" in
  FL2VA|Ref2VA) INCLUDE="$PART/*" ;;
  all) INCLUDE="*"; echo "WARN: 양 파티션 = 270GB+, 디스크 확인 필수" ;;
  *) echo "usage: $0 [FL2VA|Ref2VA|all]"; exit 2 ;;
esac

echo "== $HF_REPO ($PART) -> $H3_ROOT =="
if command -v hf >/dev/null 2>&1; then DL="hf download"; else DL="huggingface-cli download"; fi
# shellcheck disable=SC2086
(set -x; $DL "$HF_REPO" --include "$INCLUDE" --local-dir "$H3_ROOT")

echo "== 용량 확인 =="
du -sh "$H3_ROOT" "$H3_ROOT/$PART" 2>/dev/null || true

echo "== vllm-omni (canonical ~/git 참조, 핀 리비전으로 materialize) =="
# 공식 recipes.yaml 지시: 이미지 내장 vllm-omni는 구버전이라 체크아웃으로 override 필수.
# 반드시 GB10 검증 리비전(e1aa6ea, vLLM 0.26.0 대응). 최신 main은 vLLM 0.28+ 전용이라 import 깨짐.
# canonical read-only clone은 ~/git/vllm-omni에 두고 직접 손대지 말 것 (fetch만, commit/push 금지).
# 컨테이너에 마운트하는 쪽($VLLM_OMNI_SRC, 기본 $HOME/tools/vllm-omni)은 핀 리비전의
# plain copy이며 .git을 갖지 않는다 — nested/중복 clone 금지.
VLLM_OMNI_REF="${VLLM_OMNI_REF:-$HOME/git/vllm-omni}"
VLLM_OMNI_PIN="${VLLM_OMNI_PIN:-e1aa6eae75c460cd1893bc320546e81e66973831}"
VLLM_OMNI_MAT="${VLLM_OMNI_SRC:-$HOME/tools/vllm-omni}"
if [ ! -d "$VLLM_OMNI_REF/.git" ]; then
  echo "== canonical clone 없음, 새로 받음: $VLLM_OMNI_REF =="
  (set -x; git clone https://github.com/vllm-project/vllm-omni.git "$VLLM_OMNI_REF")
fi
(set -x; git -C "$VLLM_OMNI_REF" fetch --quiet 2>/dev/null) || true
git -C "$VLLM_OMNI_REF" cat-file -e "$VLLM_OMNI_PIN^{commit}" 2>/dev/null \
  || { echo "FAIL: $VLLM_OMNI_REF 에 핀 $VLLM_OMNI_PIN 없음"; exit 1; }
if [ "$VLLM_OMNI_MAT" != "$HOME/tools/vllm-omni" ]; then
  # 외부 경로 지정 시에는 관리하지 않고 존재만 확인 (남의 git repo를 지우면 안 됨).
  [ -d "$VLLM_OMNI_MAT/vllm_omni" ] \
    || { echo "FAIL: $VLLM_OMNI_MAT에 vllm-omni 없음. VLLM_OMNI_SRC 미지정(기본값) 후 재실행"; exit 1; }
  echo "external VLLM_OMNI_SRC, 관리 스킵: $VLLM_OMNI_MAT"
elif [ -d "$VLLM_OMNI_MAT/vllm_omni" ] && [ -f "$VLLM_OMNI_MAT/.vllm-omni-pin" ] \
  && [ "$(cat "$VLLM_OMNI_MAT/.vllm-omni-pin")" = "$VLLM_OMNI_PIN" ]; then
  echo "exists: $VLLM_OMNI_MAT (${VLLM_OMNI_PIN:0:9})"
elif [ -d "$VLLM_OMNI_MAT/.git" ] \
  && [ "$(git -C "$VLLM_OMNI_MAT" rev-parse HEAD 2>/dev/null)" = "$VLLM_OMNI_PIN" ] \
  && [ -z "$(git -C "$VLLM_OMNI_MAT" status --short 2>/dev/null)" ]; then
  # 구방식 legacy clone(내용이 핀과 동일, clean) -> .git만 떼고 스탬프 (in-place 마이그레이션).
  echo "== legacy clone 마이그레이션: $VLLM_OMNI_MAT/.git 제거, 스탬프 기록 =="
  rm -rf "$VLLM_OMNI_MAT/.git"
  echo "$VLLM_OMNI_PIN" > "$VLLM_OMNI_MAT/.vllm-omni-pin"
else
  echo "== materialize vllm-omni ${VLLM_OMNI_PIN:0:9} -> $VLLM_OMNI_MAT =="
  rm -rf "$VLLM_OMNI_MAT"
  mkdir -p "$VLLM_OMNI_MAT"
  (set -x; git -C "$VLLM_OMNI_REF" archive "$VLLM_OMNI_PIN" | tar -x -C "$VLLM_OMNI_MAT")
  echo "$VLLM_OMNI_PIN" > "$VLLM_OMNI_MAT/.vllm-omni-pin"
fi

echo
echo "다음: ./3-serve-fl2va.sh"
