#!/usr/bin/env bash
# 3-build: ComfyUI 도커 이미지 빌드 (NGC PyTorch 베이스, torch는 덮어쓰지 않음). 실행 순서 3/9.
# Xplore-LAB 교훈: NGC 맞춤 torch를 pip로 덮으면 CUDA 깨짐 -> torch* 패키지 제외 설치.
# torchaudio는 빌드 타임에 소스빌드 (PyPI wheel은 NGC torch와 ABI 불일치로 기동 사망).
# 6-fix-torchaudio.sh는 검증용(no-op)으로만 남는다.
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
PYTORCH_BASE="${PYTORCH_BASE:-nvcr.io/nvidia/pytorch:25.11-py3}"
TA_COMMIT="${TA_COMMIT:-87ff22e49ed0}"
IMAGE="${IMAGE:-local/minimax-h3-comfyui:v0.30.0}"

[ -d "$BASEDIR/comfyui-src" ] || { echo "FAIL: comfyui-src 없음. ./2-prepare-source.sh 먼저"; exit 1; }

echo "== Dockerfile 생성 (base=$PYTORCH_BASE, ta=$TA_COMMIT) =="
cat > "$BASEDIR/Dockerfile" <<'EOF'
ARG PYTORCH_BASE=nvcr.io/nvidia/pytorch:25.11-py3
ARG TA_COMMIT=87ff22e49ed0
FROM ${PYTORCH_BASE}
# FROM 앞 ARG는 스테ージ에서 안 보이므로 재선언 (값은 build-arg 계승)
ARG TA_COMMIT
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg libgl1 libglib2.0-0 curl ca-certificates build-essential python3-dev \
    && rm -rf /var/lib/apt/lists
WORKDIR /comfyui
COPY comfyui-src/ /comfyui/
# NGC torch 유지: torch 계열 제외하고 설치 (torchsde는 pure-python이라 유지).
# requirements가 bare name(torch, torchaudio)이라 행끝($) 매칭 필수 — 구 패턴은 뚫림.
RUN grep -viE '^(torch|torchvision|torchaudio)([ =<>]|$)' requirements.txt > /tmp/req-notorch.txt \
    && pip install --no-cache-dir -r /tmp/req-notorch.txt
# torchaudio 소스빌드 (PyPI wheel은 undefined symbol: torch_library_impl)
RUN curl -L -o /tmp/torchaudio-src.tar.gz "https://codeload.github.com/pytorch/audio/tar.gz/${TA_COMMIT}" \
    && tar xzf /tmp/torchaudio-src.tar.gz -C /tmp \
    && pip install --no-build-isolation --no-deps "/tmp/audio-${TA_COMMIT}" \
    && python -c 'import torchaudio; print(torchaudio.__version__)' \
    && rm -rf "/tmp/audio-${TA_COMMIT}" /tmp/torchaudio-src.tar.gz
EXPOSE 8188
ENTRYPOINT ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
EOF

echo "== docker build ($IMAGE) =="
(set -x; docker build --build-arg "PYTORCH_BASE=$PYTORCH_BASE" --build-arg "TA_COMMIT=$TA_COMMIT" -t "$IMAGE" "$BASEDIR")
docker images "$IMAGE" --format '{{.Repository}}:{{.Tag}} {{.Size}}'

echo
echo "다음: ./4-download.sh"
