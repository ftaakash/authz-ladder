#!/usr/bin/env bash
# KC2: verify the identity/DSP testbed network is internal (local-only, SCOPE.md), with a positive
# control proving the probe itself works. Mirrors scripts/05_net_check.sh, on pilot08k2_dsp.
# Records a services_up column so a reader knows the topology the isolation was measured under:
#  - "peer-only"    : only the busybox positive-control peer is up (host_published_ports=0 is then
#                     weak evidence for the full topology).
#  - "identity-stack": the four identity services (2 IdentityHubs + issuer + BDRS) are up; this run
#                     ALSO probes egress from INSIDE an IdentityHub container (Review 12 R1), with the
#                     peer reachable from that same container as the positive control.
source "$(dirname "$0")/../../scripts/lib.sh"
NET="${KC2_NET:-pilot08k2_dsp}"; DRV="pilot08/curl:8.11.1"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08k2-peer >/dev/null 2>&1
docker run -d --name pilot08k2-peer --network "$NET" --network-alias peer busybox:1.37 \
  sh -c 'mkdir -p /www && echo ok > /www/index.html && httpd -f -h /www -p 8080' >/dev/null 2>&1
for _ in $(seq 1 10); do [ "$(docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 3 http://peer:8080/ 2>/dev/null)" = 200 ] && break; done

# topology: is the identity stack up?
IH="pilot08k2-provider-ih"; SVC=peer-only
docker ps -q --filter name="$IH" | grep -q . && docker ps -q --filter name=pilot08k2-bdrs | grep -q . && SVC=identity-stack

dchk(){ docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null || true; }
inchk(){ docker exec "$IH" curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null || true; }
norm(){ local v="$1"; { [ -z "$v" ] || [ "$v" = 000 ]; } && echo BLOCKED || echo "$v"; }

out="$PILOT/kc2/env/net-isolation.csv"
# append (Review 12 R1): keep prior rows; add this run's rows with the services_up topology column.
[ -f "$out" ] && head -1 "$out" | grep -q services_up || { echo "network,services_up,check,expected,got,ok,commit" > "$out.new"; [ -f "$out" ] && tail -n +2 "$out" | sed "s/^/LEGACY,/" >> "$out.new" 2>/dev/null; mv "$out.new" "$out"; }
row(){ local ok=no; [ "$2" = "$3" ] && ok=yes; echo "$NET,$SVC,$1,$2,$3,$ok,$COMMIT" >> "$out"; echo "[$SVC] $1 expected=$2 got=$3 ok=$ok"; }

row network_internal_flag true "$(docker network inspect "$NET" --format '{{.Internal}}')"
row egress_control_peer_200 200 "$(dchk http://peer:8080/)"
row egress_ip_1.1.1.1 BLOCKED "$(norm "$(dchk http://1.1.1.1/)")"
row egress_dns_example.com BLOCKED "$(norm "$(dchk http://example.com/)")"
row host_published_ports 0 "$(docker ps --filter network=$NET --format '{{.Ports}}' | grep -c '\->' || true)"

# Review 12 R1: egress probed from INSIDE an IdentityHub container, peer as positive control there.
if [ "$SVC" = identity-stack ]; then
  row incontainer_peer_200 200 "$(inchk http://peer:8080/)"
  row incontainer_egress_ip_1.1.1.1 BLOCKED "$(norm "$(inchk http://1.1.1.1/)")"
  row incontainer_egress_dns BLOCKED "$(norm "$(inchk http://example.com/)")"
else
  echo "(identity stack not up: skipping in-container egress probe — run 30_up_identity.sh first)"
fi
docker rm -f pilot08k2-peer >/dev/null 2>&1
echo "---"; cat "$out"
