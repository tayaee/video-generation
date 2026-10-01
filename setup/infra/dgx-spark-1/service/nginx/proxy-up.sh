#!/usr/bin/env bash
# proxy-up: spark1에서 실행. :8188 요청을 ComfyUI 박스로 리버스프록시.
# ComfyUI 웹소켓(/ws) + 장시간 생성 폴링 대응: Upgrade 헤더, read timeout 3600s.
# 맨 뒤 자체 검증: 컨테이너 상태 + 프록시 경유 system_stats 200 확인.
set -euo pipefail

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$BASEDIR/../../../../h3.cluster.env" ]; then
  # shellcheck disable=SC1091
  . "$BASEDIR/../../../../h3.cluster.env"
fi
COMFY_HOST="${SPARK_COMFY_HOST:-spark2-p1-r0}"
COMFY_PORT="${COMFY_PORT:-8188}"
# CX7 패브릭 대역. 프록시 타겟 IP가 이 prefix가 아니면 mgmt LAN 경유로 보고 중단.
CX7_SUBNET="${CX7_SUBNET:-192.168.102.}"
LISTEN="${PROXY_LISTEN:-8188}"
NAME="proxy-8188"
CONFDIR="$BASEDIR/proxy-8188"
CONF="$CONFDIR/nginx.conf"

echo "== 이름 확인 + CX7 IP 확정 ($COMFY_HOST) =="
(set -x; getent hosts "$COMFY_HOST") \
  || { echo "FAIL: $COMFY_HOST 미확인. /etc/hosts 등록 필요"; exit 1; }
# 이름이 아닌 CX7 패브릭 IP를 nginx에 박는다 (mgmt LAN 오경유 방지).
COMFY_IP="${SPARK_COMFY_IP:-$(getent hosts "$COMFY_HOST" | awk '{print $1; exit}')}"
case "$COMFY_IP" in
  "$CX7_SUBNET"*) echo "OK: CX7 fabric IP=$COMFY_IP" ;;
  *) echo "FAIL: $COMFY_HOST->$COMFY_IP, CX7 대역($CX7_SUBNET*) 아님. CX7_SUBNET 또는 SPARK_COMFY_IP 확인"; exit 1 ;;
esac

echo "== nginx.conf 생성 =="
mkdir -p "$CONFDIR"
cat > "$CONF" <<'EOF'
events {}
http {
  access_log /dev/stdout;
  client_max_body_size 0;
  proxy_connect_timeout 10s;
  proxy_send_timeout 3600s;
  proxy_read_timeout 3600s;
  server {
    listen __LISTEN__;
    location / {
      proxy_pass http://__COMFY__;
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    }
  }
}
EOF
sed -i "s/__LISTEN__/$LISTEN/; s|__COMFY__|$COMFY_IP:$COMFY_PORT|" "$CONF"

echo "== 기존 프록시 정리 =="
(set -x; docker rm -f "$NAME" 2>/dev/null) || true

echo "== docker run ($NAME, :$LISTEN -> $COMFY_IP:$COMFY_PORT) =="
(set -x; docker run -d --name "$NAME" --restart always --net=host \
  -v "$CONF:/etc/nginx/nginx.conf:ro" \
  nginx:alpine)
sleep 2

echo "== 검증 =="
docker ps --format '{{.Names}}' | grep -qx "$NAME" \
  || { echo "FAIL: 컨테이너 없음. 로그:"; docker logs "$NAME" 2>&1 | tail -20; exit 1; }
CODE=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$LISTEN/system_stats" || true)
[ "$CODE" = "200" ] \
  || { echo "FAIL: 프록시 경유 system_stats=$CODE (ComfyUI 미기동이면 502). 로그:"; docker logs "$NAME" 2>&1 | tail -20; exit 1; }

echo
echo "OK: proxy :$LISTEN -> $COMFY_IP:$COMFY_PORT (system_stats 200)"
echo "직통 대조: curl http://$COMFY_IP:$COMFY_PORT/system_stats"
