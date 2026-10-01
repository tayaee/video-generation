ARG PYTORCH_BASE=nvcr.io/nvidia/pytorch:25.11-py3
FROM ${PYTORCH_BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists
WORKDIR /comfyui
COPY comfyui-src/ /comfyui/
# NGC torch 유지: torch/torchvision/torchaudio 제외하고 설치
RUN grep -viE '^(torch|torchvision|torchaudio)[ =<>]' requirements.txt > /tmp/req-notorch.txt \
    && pip install --no-cache-dir -r /tmp/req-notorch.txt
EXPOSE 8188
ENTRYPOINT ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
