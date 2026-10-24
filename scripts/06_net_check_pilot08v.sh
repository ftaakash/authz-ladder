#!/usr/bin/env bash
# D3 / P2: verify the KC1 network (pilot08v) is local-only, the same way 05_net_check.sh checks
# the Tractus-X network (pilot08_dsp). Boots a vanilla provider on pilot08v, then probes egress
# from the curl driver joined to the network (the gradle-image provider has no wget). Appends to
# env/net-isolation.csv with a `network` column. Evidence, not a CVE result.
# Usage: ./06_net_check_pilot08v.sh [edc-version]   (default 0.6.2)
source "$(dirname "$0")/lib.sh"   # set -euo pipefail; require_docker (checks only); COMMIT; PILOT; DRIVER_IMG
V="${1:-0.6.2}"; NET="pilot08v"
IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
jar="$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar"
[ -f "$jar" ] || { echo "no jar for $V — build it first"; exit 1; }
got="$(sha256sum "$jar" | cut -d' ' -f1)"
grep -qE "^$V,$got,[0-9]+,[0-9a-f]{7}," "$PILOT/env/vanilla-jars.csv" 2>/dev/null \
  || { echo "jar sha $got for $V not recorded at a clean commit — rebuild"; exit 1; }
trap 'docker rm -f pilot08v-netprov >/dev/null 2>&1 || true' EXIT

# internal network (create if absent; refuse a non-internal one)
if docker network inspect "$NET" >/dev/null 2>&1; then
  [ "$(docker network inspect "$NET" --format '{{.Internal}}')" = true ] || { echo "$NET not internal"; exit 1; }
else
  docker network create --internal "$NET" >/dev/null
fi

run="$PILOT/build/run-net"; mkdir -p "$run"; cp "$jar" "$run/app.jar"; cp "$PILOT/testbed/launcher/config/provider.properties" "$run/"
docker rm -f pilot08v-netprov >/dev/null 2>&1
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-netprov --network "$NET" --network-alias provider \
  -v "$run":/work -w /work "$IMG" java -Dedc.fs.config=/work/provider.properties -jar /work/app.jar >/dev/null 2>&1
for _ in $(seq 1 60); do docker logs pilot08v-netprov 2>&1 | grep -q ' ready' && break; sleep 2; done
docker logs pilot08v-netprov 2>&1 | grep -q ' ready' || { echo "provider not ready on $V"; docker logs pilot08v-netprov 2>&1 | tail -10; exit 1; }

out="$PILOT/env/net-isolation.csv"
[ -f "$out" ] || echo "network,tx_tag,check,expected,got,ok,commit" > "$out"
grep -v "^$NET," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"   # one run per network
row() { ok=no; [ "$2" = "$3" ] && ok=yes; echo "$NET,$V,$1,$2,$3,$ok,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
# egress probe from the driver container joined to the network (curl; the provider image has none)
probe() { docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null --max-time 6 "$1" >/dev/null 2>&1 && echo REACHED || echo BLOCKED; }

row network_internal_flag true "$(docker network inspect "$NET" --format '{{.Internal}}')"
# positive control: the SAME curl driver must REACH the in-network provider by name (else the
# BLOCKED rows below are meaningless), and this also proves embedded DNS + the harness path work.
row egress_probe_control REACHED "$(probe http://provider:8080/api/check/health)"
row egress_ip_1.1.1.1 BLOCKED "$(probe http://1.1.1.1)"
row egress_dns_example.com BLOCKED "$(probe https://example.com)"
row driver_to_provider_health 200 "$(docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null -w '%{http_code}' --max-time 6 http://provider:8080/api/check/health 2>/dev/null)"
row host_published_ports 0 "$(docker port pilot08v-netprov 2>/dev/null | wc -l | tr -d ' ')"
