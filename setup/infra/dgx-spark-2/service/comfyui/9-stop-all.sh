#!/usr/bin/env bash
# 9-stop-all: 전체 종료 (comfyui + vllm h3 + 상태 요약). 실행 순서 9/9 (종료 트랙 2/2).
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
(set -x; "$BASEDIR/8-stop.sh") || true

echo "== vllm h3 컨테이너 정지 (남아있으면) =="
for N in h3-fl2va h3-ref2va; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$N"; then
    (set -x; docker stop "$N" >/dev/null && docker rm "$N" >/dev/null) && echo "removed: $N"
  else
    echo "skip (없음): $N"
  fi
done

echo "== 포트 =="
for P in 8000 8188; do
  if curl -s -m 2 "http://127.0.0.1:$P/health" >/dev/null 2>&1 \
    || curl -s -m 2 "http://127.0.0.1:$P/system_stats" >/dev/null 2>&1; then
    echo "port $P: 아직 응답 있음 (수동 확인 필요)"
  else
    echo "port $P: 비어있음"
  fi
done

echo "== 메모리 =="
awk '/MemAvailable/{printf "MemAvailable: %.1f GiB\n", $2/1024/1024}' /proc/meminfo 2>/dev/null || true

echo
echo "DONE: 전체 정지"
