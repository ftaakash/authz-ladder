#!/usr/bin/env bash
# Verify the testbed network is local-only: no container egress to the internet,
# no container ports exposed to the host, while in-network traffic and embedded
# DNS still work (so the driver-container harness can reach the connectors).
# Evidence (not a test result): env/net-isolation.csv.
# Usage: ./05_net_check.sh <tx_tag>   (provider rung must be up)
source "$(dirname "$0")/lib.sh"
TX_TAG="${1:?usage: 05_net_check.sh <tx_tag>}"
out="$PILOT/env/net-isolation.csv"
[ -f "$out" ] || echo "tx_tag,check,expected,got,ok,commit" > "$out"
row() { ok=no; [ "$2" = "$3" ] && ok=yes; echo "$TX_TAG,$1,$2,$3,$ok,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }

net="$(docker network inspect "$NET" --format '{{.Internal}}')"
row network_internal_flag true "$net"

# Positive control: the SAME wget binary must REACH an in-network service. If this
# fails, wget is broken/absent and the BLOCKED egress rows below are not meaningful.
ctl="$(docker exec pilot08-provider-1 sh -c 'wget -q -T 6 -O /dev/null http://provider:8080/api/check/health && echo REACHED || echo FAILED')"
row egress_probe_control REACHED "$ctl"

# Egress by IP (bypasses DNS): an internal network has no route out -> fails.
eg_ip="$(docker exec pilot08-provider-1 sh -c 'wget -q -T 6 -O /dev/null http://1.1.1.1 2>/dev/null && echo REACHED || echo BLOCKED')"
row egress_ip_1.1.1.1 BLOCKED "$eg_ip"

# Egress by name (DNS + route out) -> also fails.
eg_dns="$(docker exec pilot08-provider-1 sh -c 'wget -q -T 6 -O /dev/null https://example.com 2>/dev/null && echo REACHED || echo BLOCKED')"
row egress_dns_example.com BLOCKED "$eg_dns"

# Embedded DNS still resolves a service name (in-network name resolution works).
dns_local="$(docker exec pilot08-provider-1 sh -c 'nslookup provider 2>/dev/null | grep -q Address && echo RESOLVES || echo NORESOLVE')"
row embedded_dns_provider RESOLVES "$dns_local"

# Driver container reaches the connector by name (the harness path works).
dh="$(drv -s -o /dev/null -w '%{http_code}' --max-time 6 http://provider:8080/api/check/health)"
row driver_to_provider_health 200 "$dh"

# No container port is published to the host (nothing exposed off-box).
pub="$(docker port pilot08-provider-1 2>/dev/null | wc -l | tr -d ' ')"
row host_published_ports 0 "$pub"
