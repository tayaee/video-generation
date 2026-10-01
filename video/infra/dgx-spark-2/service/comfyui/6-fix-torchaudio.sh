#!/usr/bin/env bash
# 6-fix-torchaudio: torchaudio 확인 (3-build.sh가 빌드 타임에 소스빌드済).
# 구 플로우(기동 컨테이너 내 빌드+commit)는 폐기 — 이 스크립트는 검증용 no-op.
# import 실패 시에만 여기서 원인 파악 후 3-build.sh를 고칠 것.
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
NAME="h3-comfyui"
TA_COMMIT="${TA_COMMIT:-87ff22e49ed0}"
FIXED_IMAGE="${FIXED_IMAGE:-local/minimax-h3-comfyui:v0.30.0-ta}"
TARBALL="/tmp/torchaudio-src.tar.gz"

docker ps --format '{{.Names}}' | grep -qx "$NAME" \
  || { echo "FAIL: $NAME 실행중 아님. ./5-up.sh 먼저"; exit 1; }

if docker exec "$NAME" python -c "import torchaudio" 2>/dev/null; then
  echo "OK: torchaudio 이미 있음 ($(docker exec "$NAME" python -c "import torchaudio; print(torchaudio.__version__)" 2>/dev/null)). 스킵."
  exit 0
fi

echo "== torchaudio 소스 확보 ($TA_COMMIT) =="
(set -x; curl -L -o "$TARBALL" "https://codeload.github.com/pytorch/audio/tar.gz/$TA_COMMIT")
(set -x; docker cp "$TARBALL" "$NAME:/tmp/")

echo "== 컨테이너 내 빌드 (수 분 소요) =="
(set -x; docker exec "$NAME" bash -c "
  cd /tmp && tar xzf torchaudio-src.tar.gz \
  && pip install --no-build-isolation --no-deps /tmp/audio-${TA_COMMIT} \
  && python -c 'import torchaudio; print(torchaudio.__version__)'")

echo "== 이미지固定 ($FIXED_IMAGE) =="
(set -x; docker commit "$NAME" "$FIXED_IMAGE")
docker inspect "$FIXED_IMAGE" --format 'committed: {{.Id}} {{.Size}}'

echo "== 고정 이미지로 재기동 =="
(set -x; IMAGE="$FIXED_IMAGE" "$BASEDIR/5-up.sh")
docker exec "$NAME" python -c "import torchaudio; print('verify:', torchaudio.__version__)"

echo
echo "다음: ./7-first-video.sh"
