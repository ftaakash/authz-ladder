#!/usr/bin/env bash
# KC2 handshake library (generic infrastructure, local testbed only). Sourced by the tracked bring-up
# (40_up_handshake.sh) and by private assertion runners under private/kc2/. Contains NO assertions and
# NO results: it only boots participants on the internal network.
#
#   kc2_didweb_up                       serve issuer did:web documents (issuer, untrusted-j) at :8099
#   kc2_boot_ih   ID DIDPORT BPN ISSUER  IdentityHub for ID; seeds participant + MembershipCredential
#                                        signed by ISSUER (a GenIssuer key name under testbed/.secrets/kc2)
#   kc2_boot_bdrs / kc2_seed_bdrs BPN DID
#   kc2_boot_conn ID BPN IHPORT [EXTRA_TRUSTED_ISSUER_DID]
#                                        Tractus-X connector; trusts the issuer, plus an optional extra one
#   kc2_ready CONTAINER REGEX / kc2_drv CURL-ARGS...
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
CONN_IMG="${CONN_IMG:-pilot08k2/edc-runtime-memory:0.13.0}"
NET="pilot08k2_dsp"; S="$PILOT/testbed/.secrets/kc2"
IHJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-identityhub-0.17.0.jar"
IDID="did:web:issuer%3A8099:issuer"
kc2_did(){ echo "did:web:$1-ih%3A$2:$1"; }                 # participant DID for ID at DIDPORT
kc2_issuer_did(){ echo "did:web:$1%3A8099:$1"; }          # issuer DID for issuer key name

kc2_drv(){ docker run --rm --network "$NET" pilot08/curl:8.11.1 "$@" 2>/dev/null; }
kc2_ready(){ for _ in $(seq 1 60); do docker logs "$1" 2>&1 | grep -qE "$2" && return 0; docker ps -q --filter name="$1"|grep -q . || return 1; done; return 1; }

kc2_net_up(){ docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null; }

kc2_didweb_up(){
  local w="$PILOT/build/kc2-didweb"; mkdir -p "$w/issuer" "$w/untrusted-j"
  cp "$S/issuer.did.json" "$w/issuer/did.json"; cp "$S/untrusted-j.did.json" "$w/untrusted-j/did.json"
  docker rm -f pilot08k2-issuer-did >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-issuer-did --network "$NET" --network-alias issuer --network-alias untrusted-j \
    -v "$w":/www busybox:1.37 httpd -f -h /www -p 8099 >/dev/null 2>&1
}

kc2_boot_ih(){
  local id="$1"; local didport="$2"; local bpn="$3"; local issuer="$4"
  local run="$PILOT/build/kc2-$id-ih"; mkdir -p "$run"
  cp "$IHJAR" "$run/ih.jar"; cp "$S/$issuer.priv.jwk" "$run/issuer.priv.jwk"
  cat > "$run/cfg.properties" <<EOF
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
pilot08.kc2.seed.participant.did=$(kc2_did "$id" "$didport")
pilot08.kc2.seed.sts.client.secret=$id-sts-secret
pilot08.kc2.seed.bpn=$bpn
pilot08.kc2.seed.credentialservice.url=${KC2_CREDSVC_URL:-http://$id-ih:7082/api/credentials/v1/participants/$id}
pilot08.kc2.issuer.did=$(kc2_issuer_did "$issuer")
pilot08.kc2.issuer.privjwk.path=/work/issuer.priv.jwk
pilot08.kc2.issuer.keyid=key-1
pilot08.kc2.txscope.enabled=${KC2_TXSCOPE:-true}
EOF
  docker rm -f "pilot08k2-$id-ih" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id-ih" --network "$NET" --network-alias "$id-ih" \
    -v "$run":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/ih.jar ${IH_ARGS:-} >/dev/null 2>&1
}

kc2_boot_bdrs(){
  docker rm -f pilot08k2-bdrs >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-bdrs --network "$NET" --network-alias bdrs \
    -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api \
    -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
    -e WEB_HTTP_MANAGEMENT_AUTH_KEY=bdrs-mgmt \
    -e EDC_IAM_DID_WEB_USE_HTTPS=false -e EDC_IAM_ISSUER_ID="$IDID" \
    pilot08k2/bdrs-server-memory:0.6.0 >/dev/null 2>&1
}
kc2_seed_bdrs(){ kc2_drv -s -o /dev/null -w '%{http_code}' -X POST http://bdrs:8081/management/bpn-directory \
    -H 'x-api-key: bdrs-mgmt' -H 'content-type: application/json' -d "{\"bpn\":\"$1\",\"did\":\"$2\"}"; }

kc2_boot_conn(){
  local id="$1"; local bpn="$2"; local ihport="$3"; local extra="${4:-}"
  local did; did="$(kc2_did "$id" "$ihport")"
  local sigpriv; sigpriv="$(cat "$S/$id-signer.priv.jwk")"
  local sigpub; sigpub="$(cat "$S/$id-signer.pub.jwk")"
  local secrets="$id-sts:$id-sts-secret;$id-signer:$sigpriv;$id-verifier:$sigpub"
  local extra_env=()
  [ -n "$extra" ] && extra_env=(-e "EDC_IAM_TRUSTEDISSUER_EXTRA_ID=$extra")
  docker rm -f "pilot08k2-$id" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id" --network "$NET" --network-alias "$id" \
    -e EDC_PARTICIPANT_ID="$did" \
    -e EDC_API_AUTH_KEY="$id-mgmt" \
    -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api \
    -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
    -e WEB_HTTP_PROTOCOL_PORT=8082 -e WEB_HTTP_PROTOCOL_PATH=/api/v1/dsp \
    -e WEB_HTTP_CONTROL_PORT=8083 -e WEB_HTTP_CONTROL_PATH=/control \
    -e WEB_HTTP_PUBLIC_PORT=8085 -e WEB_HTTP_PUBLIC_PATH=/public \
    -e EDC_DSP_CALLBACK_ADDRESS="http://$id:8082/api/v1/dsp" \
    -e EDC_IAM_ISSUER_ID="$did" \
    -e EDC_IAM_DID_WEB_USE_HTTPS=false \
    -e EDC_IAM_STS_OAUTH_TOKEN_URL="http://$id-ih:7083/api/sts/token" \
    -e EDC_IAM_STS_OAUTH_CLIENT_ID="$did" \
    -e EDC_IAM_STS_OAUTH_CLIENT_SECRET_ALIAS="$id-sts" \
    -e TX_EDC_IAM_DCP_CREDENTIALSERVICE_URL="http://$id-ih:7082/api/credentials/v1/participants/$id" \
    -e TX_EDC_IAM_DCP_BDRS_SERVER_URL="http://bdrs:8080/api" \
    -e EDC_IAM_TRUSTEDISSUER_PILOT_ID="$IDID" \
    "${extra_env[@]}" \
    -e EDC_TRANSFER_PROXY_TOKEN_SIGNER_PRIVATEKEY_ALIAS="$id-signer" \
    -e EDC_TRANSFER_PROXY_TOKEN_VERIFIER_PUBLICKEY_ALIAS="$id-verifier" \
    -e TX_EDC_VAULT_SECRETS="$secrets" \
    -e TRACTUSX_EDC_PARTICIPANT_BPN="$bpn" \
    -e OTEL_JAVAAGENT_ENABLED=false \
    "$CONN_IMG" ${CONN_ARGS:-} >/dev/null 2>&1
}

# catalogue request FROM connector $1 TO provider; prints HTTP code
kc2_catalog_code(){ local from="$1"; local pdid; pdid="$(kc2_did provider 7084)"
  kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 40 -X POST "http://$from:8081/management/v3/catalog/request" \
    -H "x-api-key: $from-mgmt" -H 'content-type: application/json' \
    -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"CatalogRequest","counterPartyAddress":"http://provider:8082/api/v1/dsp","counterPartyId":"'"$pdid"'","protocol":"dataspace-protocol-http"}'; }

# ---- vanilla Eclipse EDC 0.18.1 target (container pilot08k2-v<ID>, alias v<ID>) ----
VJAR="$PILOT/kc2/vanilla/build/libs/pilot08kc2-vanilla-0.18.1.jar"
DCP_ALIAS_SCOPE="org.eclipse.dspace.dcp.vc.type:MembershipCredential:read"
kc2_boot_vconn(){
  local id="$1"; local ihport="$2"; local extra="${3:-}"
  local did; did="$(kc2_did "$id" "$ihport")"
  local run="$PILOT/build/kc2-v$id"; mkdir -p "$run"; cp "$VJAR" "$run/app.jar"
  local sigpriv; sigpriv="$(cat "$S/$id-signer.priv.jwk")"
  local sigpub; sigpub="$(cat "$S/$id-signer.pub.jwk")"
  cat > "$run/cfg.properties" <<EOF2
edc.participant.id=$did
edc.iam.issuer.id=$did
edc.hostname=v$id
edc.iam.did.web.use.https=false
web.http.port=8080
web.http.path=/api
web.http.management.port=8081
web.http.management.path=/management
web.http.management.auth.type=tokenbased
web.http.management.auth.key=v$id-mgmt
web.http.protocol.port=8082
web.http.protocol.path=/api/v1/dsp
web.http.control.port=8083
web.http.control.path=/control
web.http.public.port=8085
web.http.public.path=/public
edc.dsp.callback.address=http://v$id:8082/api/v1/dsp
edc.iam.sts.oauth.token.url=http://$id-ih:7083/api/sts/token
edc.iam.sts.oauth.client.id=$did
edc.iam.sts.oauth.client.secret.alias=$id-sts
edc.iam.trustedissuer.pilot.id=$IDID
edc.iam.dcp.scopes.membership.id=membership
edc.iam.dcp.scopes.membership.type=DEFAULT
edc.iam.dcp.scopes.membership.value=$DCP_ALIAS_SCOPE
edc.transfer.proxy.token.signer.privatekey.alias=$id-signer
edc.transfer.proxy.token.verifier.publickey.alias=$id-verifier
pilot08.kc2.vault.secrets=$id-sts:$id-sts-secret;$id-signer:$sigpriv;$id-verifier:$sigpub
EOF2
  [ -n "$extra" ] && echo "edc.iam.trustedissuer.extra.id=$extra" >> "$run/cfg.properties"
  docker rm -f "pilot08k2-v$id" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-v$id" --network "$NET" --network-alias "v$id" \
    -v "$run":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/app.jar ${CONN_ARGS:-} >/dev/null 2>&1
}
# catalogue request FROM vanilla connector v$1 TO vprovider; prints HTTP code
kc2_vcatalog_code(){ local from="$1"; local pdid; pdid="$(kc2_did provider 7084)"
  kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 40 -X POST "http://v$from:8081/management/v3/catalog/request" \
    -H "x-api-key: v$from-mgmt" -H 'content-type: application/json' \
    -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"CatalogRequest","counterPartyAddress":"http://vprovider:8082/api/v1/dsp/2025-1","counterPartyId":"'"$pdid"'","protocol":"dataspace-protocol-http:2025-1"}'; }
