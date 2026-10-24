#!/usr/bin/env bash
# KC2: verify the identity/DSP testbed network is internal (local-only, SCOPE.md), with a positive
# control proving the probe itself works. Mirrors scripts/05_net_check.sh, on pilot08k2_dsp.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${KC2_NET:-pilot08k2_dsp}"; DRV="pilot08/curl:8.11.1"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08k2-peer >/dev/null 2>&1
# in-network HTTP peer that returns 200 (positive control that the probe + network path work)
docker run -d --name pilot08k2-peer --network "$NET" --network-alias peer busybox:1.37 \
  sh -c 'mkdir -p /www && echo ok > /www/index.html && httpd -f -h /www -p 8080' >/dev/null 2>&1
for _ in $(seq 1 10); do [ "$(docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 3 http://peer:8080/ 2>/dev/null)" = 200 ] && break; done
dchk() { docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null || true; }
out="$PILOT/kc2/env/net-isolation.csv"; echo "network,check,expected,got,ok,commit" > "$out"
row(){ local ok=no; [ "$2" = "$3" ] && ok=yes; echo "$NET,$1,$2,$3,$ok,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
row network_internal_flag true "$(docker network inspect "$NET" --format '{{.Internal}}')"
row egress_control_peer_200 200 "$(dchk http://peer:8080/)"
e="$(dchk http://1.1.1.1/)"; { [ -z "$e" ] || [ "$e" = 000 ]; } && e=BLOCKED; row egress_ip_1.1.1.1 BLOCKED "$e"
d="$(dchk http://example.com/)"; { [ -z "$d" ] || [ "$d" = 000 ]; } && d=BLOCKED; row egress_dns_example.com BLOCKED "$d"
row host_published_ports 0 "$(docker ps --filter network=$NET --format '{{.Ports}}' | grep -c '\->' || true)"
docker rm -f pilot08k2-peer >/dev/null 2>&1
echo "---"; cat "$out"
