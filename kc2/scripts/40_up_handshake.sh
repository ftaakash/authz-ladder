#!/usr/bin/env bash
# KC2 step 2 — DCP handshake bring-up (local testbed only, internal network).
# Stack: issuer did:web server, provider-ih + consumer-ih (IdentityHub 0.17.0, each seeds its participant
# + MembershipCredential), BDRS (seeded BPN->DID), provider + consumer connectors (Tractus-X 0.13.0).
# Drives a consumer->provider catalogue over DSP and reports the HTTP code (the trusted-issuer 200 is the
# positive control). Infra rows -> kc2/env/handshake-smoke.csv; invariant assertions are NOT run here.
# Debug-oriented: prints connector logs on failure.
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
CONN_IMG="pilot08k2/edc-runtime-memory:0.13.0"
NET="pilot08k2_dsp"; S="$PILOT/testbed/.secrets/kc2"
IHJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-identityhub-0.17.0.jar"
b64(){ printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '='; }
# Jar guard (KC1 style): the IdentityHub jar must be recorded at a CLEAN commit in identity-jars.csv.
IHSHA="$(sha256sum "$IHJAR" | cut -d' ' -f1)"
grep -qE "^identityhub,[0-9.]+,$IHSHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/identity-jars.csv" 2>/dev/null \
  || { echo "IdentityHub jar sha $IHSHA not recorded at a clean commit — run 10_build_identity.sh on a clean tree"; exit 1; }
CONN_DIGEST="$(docker image inspect "$CONN_IMG" --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//')"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null

PDID="did:web:provider-ih%3A7084:provider"; CDID="did:web:consumer-ih%3A7086:consumer"
IDID="did:web:issuer%3A8099:issuer"
PBPN="BPNL000000PROVIDER"; CBPN="BPNL000000CONSUMER"

echo "== did:web server (issuer, untrusted-j) =="
W="$PILOT/build/kc2-didweb"; mkdir -p "$W/issuer" "$W/untrusted-j"
cp "$S/issuer.did.json" "$W/issuer/did.json"; cp "$S/untrusted-j.did.json" "$W/untrusted-j/did.json"
docker rm -f pilot08k2-issuer-did >/dev/null 2>&1
MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-issuer-did --network "$NET" --network-alias issuer --network-alias untrusted-j -v "$W":/www busybox:1.37 httpd -f -h /www -p 8099 >/dev/null 2>&1

boot_ih(){ # id didport bpn
  local id="$1"; local didport="$2"; local bpn="$3"; local run="$PILOT/build/kc2-$id-ih"; mkdir -p "$run"
  cp "$IHJAR" "$run/ih.jar"; cp "$S/issuer.priv.jwk" "$run/issuer.priv.jwk"
  cat > "$run/cfg.properties" <<EOF
edc.runtime.id=$id-ih
web.http.port=7080
web.http.path=/api
web.http.identity.port=7081
web.http.identity.path=/api/identity
web.http.credentials.port=7082
web.http.credentials.path=/api/credentials
web.http.sts.port=7083
web.http.sts.path=/api/sts
web.http.did.port=$didport
web.http.did.path=/
edc.iam.did.web.use.https=false
edc.encryption.aes.key.alias=aes-encryption-key
pilot08.kc2.seed.participant.id=$id
pilot08.kc2.seed.participant.did=did:web:$id-ih%3A$didport:$id
pilot08.kc2.seed.sts.client.secret=$id-sts-secret
pilot08.kc2.seed.bpn=$bpn
pilot08.kc2.seed.credentialservice.url=http://$id-ih:7082/api/credentials/v1/participants/$id
pilot08.kc2.issuer.did=$IDID
pilot08.kc2.issuer.privjwk.path=/work/issuer.priv.jwk
pilot08.kc2.issuer.keyid=key-1
EOF
  docker rm -f "pilot08k2-$id-ih" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id-ih" --network "$NET" --network-alias "$id-ih" -v "$run":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/ih.jar >/dev/null 2>&1
}
echo "== IdentityHubs =="; boot_ih provider 7084 "$PBPN"; boot_ih consumer 7086 "$CBPN"

echo "== BDRS =="
docker rm -f pilot08k2-bdrs >/dev/null 2>&1
MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-bdrs --network "$NET" --network-alias bdrs \
  -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api \
  -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
  -e WEB_HTTP_MANAGEMENT_AUTH_KEY=bdrs-mgmt \
  -e EDC_IAM_DID_WEB_USE_HTTPS=false -e EDC_IAM_ISSUER_ID="$IDID" \
  pilot08k2/bdrs-server-memory:0.6.0 >/dev/null 2>&1

ready(){ for _ in $(seq 1 60); do docker logs "$1" 2>&1 | grep -qE "$2" && return 0; docker ps -q --filter name="$1"|grep -q . || return 1; done; return 1; }
ready pilot08k2-provider-ih "stored MembershipCredential for 'provider'" && echo "provider-ih ok" || { echo "provider-ih NOT ready"; docker logs pilot08k2-provider-ih 2>&1|tail -8; }
ready pilot08k2-consumer-ih "stored MembershipCredential for 'consumer'" && echo "consumer-ih ok" || { echo "consumer-ih NOT ready"; docker logs pilot08k2-consumer-ih 2>&1|tail -8; }
ready pilot08k2-bdrs " ready" && echo "bdrs ok" || { echo "bdrs NOT ready"; docker logs pilot08k2-bdrs 2>&1|tail -8; }

echo "== seed BDRS directory (BPN->DID) =="
drv(){ docker run --rm --network "$NET" pilot08/curl:8.11.1 "$@" 2>/dev/null; }
for kv in "$PBPN:$PDID" "$CBPN:$CDID"; do
  drv -s -o /dev/null -w "bdrs seed ${kv%%:*} %{http_code}\n" -X POST http://bdrs:8081/management/bpn-directory \
    -H 'x-api-key: bdrs-mgmt' -H 'content-type: application/json' -d "{\"bpn\":\"${kv%%:*}\",\"did\":\"${kv#*:}\"}"
done

boot_conn(){ # id bpn didport-of-ih
  local id="$1"; local bpn="$2"; local ihport="$3"
  local sigpriv; sigpriv="$(cat "$S/$id-signer.priv.jwk")"
  local sigpub; sigpub="$(cat "$S/$id-signer.pub.jwk")"
  local secrets="$id-sts:$id-sts-secret;$id-signer:$sigpriv;$id-verifier:$sigpub"
  docker rm -f "pilot08k2-$id" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id" --network "$NET" --network-alias "$id" \
    -e EDC_PARTICIPANT_ID="did:web:$id-ih%3A$ihport:$id" \
    -e EDC_API_AUTH_KEY="$id-mgmt" \
    -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api \
    -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
    -e WEB_HTTP_PROTOCOL_PORT=8082 -e WEB_HTTP_PROTOCOL_PATH=/api/v1/dsp \
    -e WEB_HTTP_CONTROL_PORT=8083 -e WEB_HTTP_CONTROL_PATH=/control \
    -e WEB_HTTP_PUBLIC_PORT=8085 -e WEB_HTTP_PUBLIC_PATH=/public \
    -e EDC_DSP_CALLBACK_ADDRESS="http://$id:8082/api/v1/dsp" \
    -e EDC_IAM_ISSUER_ID="did:web:$id-ih%3A$ihport:$id" \
    -e EDC_IAM_DID_WEB_USE_HTTPS=false \
    -e EDC_IAM_STS_OAUTH_TOKEN_URL="http://$id-ih:7083/api/sts/token" \
    -e EDC_IAM_STS_OAUTH_CLIENT_ID="did:web:$id-ih%3A$ihport:$id" \
    -e EDC_IAM_STS_OAUTH_CLIENT_SECRET_ALIAS="$id-sts" \
    -e TX_EDC_IAM_DCP_CREDENTIALSERVICE_URL="http://$id-ih:7082/api/credentials/v1/participants/$id" \
    -e TX_EDC_IAM_DCP_BDRS_SERVER_URL="http://bdrs:8080/api" \
    -e EDC_IAM_TRUSTEDISSUER_PILOT_ID="$IDID" \
    -e EDC_TRANSFER_PROXY_TOKEN_SIGNER_PRIVATEKEY_ALIAS="$id-signer" \
    -e EDC_TRANSFER_PROXY_TOKEN_VERIFIER_PUBLICKEY_ALIAS="$id-verifier" \
    -e TX_EDC_VAULT_SECRETS="$secrets" \
    -e TRACTUSX_EDC_PARTICIPANT_BPN="$bpn" \
    -e OTEL_JAVAAGENT_ENABLED=false \
    "$CONN_IMG" ${CONN_ARGS:-} >/dev/null 2>&1
}
echo "== connectors =="; boot_conn provider "$PBPN" 7084; boot_conn consumer "$CBPN" 7086
ready pilot08k2-provider " ready" && echo "provider ok" || { echo "provider NOT ready"; docker logs pilot08k2-provider 2>&1|tail -15; }
ready pilot08k2-consumer " ready" && echo "consumer ok" || { echo "consumer NOT ready"; docker logs pilot08k2-consumer 2>&1|tail -15; }

echo "== consumer -> provider catalogue (DCP) =="
# Tracked smoke = INFRASTRUCTURE rows only (Review 13 S3): readiness, BDRS seeding, the DSP no-token
# refusal baseline, and the DCP-authenticated catalogue with the TRUSTED issuer (positive control).
# Invariant assertions (untrusted issuer, cross-party, sanity-vs-mutation) are never written here.
out="$PILOT/kc2/env/handshake-smoke.csv"
[ -f "$out" ] || echo "target,check,expected,got,ok,connector_digest,identityhub_jar_sha256,commit" > "$out"
row(){ local ok=no; [ "$2" = "$3" ] && ok=yes; echo "tractusx-0.13.0,$1,$2,$3,$ok,$CONN_DIGEST,$IHSHA,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
st(){ docker logs "$1" 2>&1 | grep -qE "$2" && echo ready || echo notready; }
row provider_ih_seeded_with_credential ready "$(st pilot08k2-provider-ih "stored MembershipCredential for 'provider'")"
row consumer_ih_seeded_with_credential ready "$(st pilot08k2-consumer-ih "stored MembershipCredential for 'consumer'")"
row bdrs_booted ready "$(st pilot08k2-bdrs " ready")"
row provider_connector_booted ready "$(st pilot08k2-provider " ready")"
row consumer_connector_booted ready "$(st pilot08k2-consumer " ready")"
row issuer_did_resolves 200 "$(drv -s -o /dev/null -w '%{http_code}' --max-time 8 http://issuer:8099/issuer/did.json)"
row dsp_catalog_no_token 401 "$(drv -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST http://provider:8082/api/v1/dsp/catalog/request -H 'content-type: application/json' -d '{"@context":{"dspace":"https://w3id.org/dspace/v0.8/"},"@type":"dspace:CatalogRequestMessage","dspace:filter":{}}')"
REQ='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"CatalogRequest","counterPartyAddress":"http://provider:8082/api/v1/dsp","counterPartyId":"'"$PDID"'","protocol":"dataspace-protocol-http"}'
body="$(drv -s --max-time 40 -X POST http://consumer:8081/management/v3/catalog/request -H 'x-api-key: consumer-mgmt' -H 'content-type: application/json' -d "$REQ")"
code="$(drv -s -o /dev/null -w '%{http_code}' --max-time 40 -X POST http://consumer:8081/management/v3/catalog/request -H 'x-api-key: consumer-mgmt' -H 'content-type: application/json' -d "$REQ")"
row dcp_catalog_trusted_issuer 200 "$code"
row dcp_catalog_body_type dcat:Catalog "$(echo "$body" | "$JQ" -r '."@type"' 2>/dev/null)"
echo "---"; tail -n 9 "$out"
