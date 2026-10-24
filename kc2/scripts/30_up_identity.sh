#!/usr/bin/env bash
# KC2 phase-2 milestone bring-up (local testbed only, internal network): two IdentityHubs
# (provider-ih, consumer-ih), one IssuerService, one BDRS. Each IdentityHub seeds exactly one
# participant context (via the Kc2SeedExtension), which generates its keypair and publishes its
# did:web document. Then verify did:web resolution BETWEEN the participants over the internal net.
# NO credential issuance and NO connector DCP handshake here (deferred, per the phase-2 milestone).
# Records kc2/env/identity-smoke.csv (testbed sanity, not a KC2 test result).
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
NET="pilot08k2_dsp"; K2="$PILOT/kc2"; DRV="pilot08/curl:8.11.1"
IHJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-identityhub-0.17.0.jar"
ISJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-issuer-0.17.0.jar"
BDRS_IMG="pilot08k2/bdrs-server-memory:0.6.0"
for j in "$IHJAR" "$ISJAR"; do [ -f "$j" ] || { echo "missing $j — run kc2/scripts/10_build_identity.sh"; exit 1; }; done
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null

# --- IdentityHub config template: $1=participant id, $2=did host:port alias ---
mk_ih_cfg() {
  local id="$1" didport="$2" dir="$PILOT/build/kc2-$id-ih"; mkdir -p "$dir"
  cp "$IHJAR" "$dir/ih.jar"
  cat > "$dir/cfg.properties" <<EOF
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
web.http.version.port=7085
web.http.version.path=/api/version
edc.iam.did.web.use.https=false
edc.encryption.aes.key.alias=aes-encryption-key
pilot08.kc2.seed.participant.id=$id
pilot08.kc2.seed.participant.did=did:web:$id-ih%3A$didport:$id
pilot08.kc2.seed.key.alias=$id-private-key
pilot08.kc2.seed.key.id=$id-key-1
EOF
  echo "$dir"
}

boot_ih() {
  local id="$1" didport="$2"; local dir; dir="$(mk_ih_cfg "$id" "$didport")"
  docker rm -f "pilot08k2-$id-ih" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id-ih" --network "$NET" --network-alias "$id-ih" \
    -v "$dir":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/ih.jar >/dev/null 2>&1
}

# --- issuer ---
boot_issuer() {
  local dir="$PILOT/build/kc2-issuer"; mkdir -p "$dir"; cp "$ISJAR" "$dir/issuer.jar"
  cat > "$dir/cfg.properties" <<EOF
edc.runtime.id=issuer
web.http.port=8090
web.http.path=/api
web.http.issueradmin.port=8091
web.http.issueradmin.path=/api/admin
web.http.issuance.port=8092
web.http.issuance.path=/api/issuance
web.http.did.port=8093
web.http.did.path=/
edc.iam.did.web.use.https=false
EOF
  docker rm -f pilot08k2-issuer >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-issuer --network "$NET" --network-alias issuer \
    -v "$dir":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/issuer.jar >/dev/null 2>&1
}

# --- BDRS (official in-memory server) ---
boot_bdrs() {
  docker rm -f pilot08k2-bdrs >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-bdrs --network "$NET" --network-alias bdrs \
    -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api \
    -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
    -e WEB_HTTP_MANAGEMENT_AUTH_KEY=pilot08k2-bdrs-mgmt \
    -e EDC_IAM_DID_WEB_USE_HTTPS=false \
    -e EDC_API_AUTH_KEY=pilot08k2-bdrs-mgmt \
    "$BDRS_IMG" >/dev/null 2>&1
}

ready() { # $1 container  $2 "ready" grep
  for _ in $(seq 1 50); do docker logs "$1" 2>&1 | grep -qE "$2" && return 0; docker ps -q --filter name="$1" | grep -q . || return 1; done; return 1
}

echo "booting provider-ih, consumer-ih, issuer, bdrs on $NET ..."
boot_ih provider 7084; boot_ih consumer 7086; boot_issuer; boot_bdrs

out="$K2/env/identity-smoke.csv"; echo "service,check,expected,got,ok,commit" > "$out"
row(){ local ok=no; [ "$3" = "$4" ] && ok=yes; echo "$1,$2,$3,$4,$ok,$COMMIT" >> "$out"; echo "$1/$2 expected=$3 got=$4 ok=$ok"; }
hc(){ docker run --rm --network "$NET" "$DRV" -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null || true; }
body(){ docker run --rm --network "$NET" "$DRV" -s --max-time 6 "$@" 2>/dev/null || true; }

ready pilot08k2-provider-ih "seeded participant 'provider'" && pv=ready || pv=notready
ready pilot08k2-consumer-ih "seeded participant 'consumer'" && cv=ready || cv=notready
ready pilot08k2-issuer " ready" && iv=ready || iv=notready
ready pilot08k2-bdrs " ready" && bv=ready || bv=notready
row provider-ih seed_ready ready "$pv"
row consumer-ih seed_ready ready "$cv"
row issuer boot_ready ready "$iv"
row bdrs boot_ready ready "$bv"

# did:web resolution between the participants, over the internal network (cross-container):
row did provider_did_200 200 "$(hc http://provider-ih:7084/provider/did.json)"
row did consumer_did_200 200 "$(hc http://consumer-ih:7086/consumer/did.json)"
# each participant's DID document must carry a published Ed25519 verification method
pvm="$(body http://provider-ih:7084/provider/did.json | "$JQ" -r '.verificationMethod[0].publicKeyJwk.crv' 2>/dev/null)"
cvm="$(body http://consumer-ih:7086/consumer/did.json | "$JQ" -r '.verificationMethod[0].publicKeyJwk.crv' 2>/dev/null)"
row did provider_vm_Ed25519 Ed25519 "${pvm:-none}"
row did consumer_vm_Ed25519 Ed25519 "${cvm:-none}"
echo "---"; cat "$out"
