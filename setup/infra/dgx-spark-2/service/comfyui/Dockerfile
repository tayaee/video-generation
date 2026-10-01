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
