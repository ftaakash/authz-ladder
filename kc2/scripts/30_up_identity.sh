#!/usr/bin/env bash
# KC2 phase-2 milestone bring-up (local testbed only, internal network): two IdentityHubs
# (provider-ih, consumer-ih), one IssuerService, one BDRS. Each IdentityHub seeds exactly one
# participant context (Kc2SeedExtension), generating its keypair and publishing its did:web doc.
# Verifies did:web resolution BETWEEN participants, exec'd FROM inside each IdentityHub container
# (true cross-resolution over the internal net, not via a third driver). NO credential issuance
# and NO DCP handshake (deferred per the phase-2 milestone). Records kc2/env/identity-smoke.csv.
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
NET="pilot08k2_dsp"; K2="$PILOT/kc2"
IHJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-identityhub-0.17.0.jar"
ISJAR="$PILOT/kc2/identity/build/libs/pilot08kc2-issuer-0.17.0.jar"
BDRS_IMG="pilot08k2/bdrs-server-memory:0.6.0"
for j in "$IHJAR" "$ISJAR"; do [ -f "$j" ] || { echo "missing $j — run kc2/scripts/10_build_identity.sh"; exit 1; }; done

# R4 jar guard (KC1 style): the IdentityHub jar about to run must match a CLEAN-commit row in
# identity-jars.csv, so the smoke can never silently run a stale/dirty jar.
IHSHA="$(sha256sum "$IHJAR" | cut -d' ' -f1)"
grep -qE "^identityhub,[0-9.]+,$IHSHA,[0-9]+,[0-9a-f]{7}," "$K2/env/identity-jars.csv" 2>/dev/null \
  || { echo "IdentityHub jar sha $IHSHA not recorded at a clean commit — rebuild on a clean tree (10_build_identity.sh)"; exit 1; }

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null

mk_ih_cfg() {
  local id="$1" didport="$2" dir="$PILOT/build/kc2-$id-ih"; mkdir -p "$dir"; cp "$IHJAR" "$dir/ih.jar"
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
pilot08.kc2.seed.key.id=did:web:$id-ih%3A$didport:$id#$id-key-1
EOF
  echo "$dir"
}
boot_ih(){ local id="$1" didport="$2" dir; dir="$(mk_ih_cfg "$id" "$didport")"; docker rm -f "pilot08k2-$id-ih" >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name "pilot08k2-$id-ih" --network "$NET" --network-alias "$id-ih" -v "$dir":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/ih.jar >/dev/null 2>&1; }
boot_issuer(){ local dir="$PILOT/build/kc2-issuer"; mkdir -p "$dir"; cp "$ISJAR" "$dir/issuer.jar"
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
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-issuer --network "$NET" --network-alias issuer -v "$dir":/work -w /work "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/issuer.jar >/dev/null 2>&1; }
boot_bdrs(){ docker rm -f pilot08k2-bdrs >/dev/null 2>&1
  MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-bdrs --network "$NET" --network-alias bdrs \
    -e WEB_HTTP_PORT=8080 -e WEB_HTTP_PATH=/api -e WEB_HTTP_MANAGEMENT_PORT=8081 -e WEB_HTTP_MANAGEMENT_PATH=/management \
    -e WEB_HTTP_MANAGEMENT_AUTH_KEY=pilot08k2-bdrs-mgmt -e EDC_IAM_DID_WEB_USE_HTTPS=false -e EDC_API_AUTH_KEY=pilot08k2-bdrs-mgmt \
    "$BDRS_IMG" >/dev/null 2>&1; }
ready(){ for _ in $(seq 1 60); do docker logs "$1" 2>&1 | grep -qE "$2" && return 0; docker ps -q --filter name="$1" | grep -q . || return 1; done; return 1; }
# curl exec'd INSIDE a container (true host-to-host over the internal net)
inhc(){ local c="$1"; shift; docker exec "$c" curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null || true; }
inbody(){ local c="$1"; shift; docker exec "$c" curl -s --max-time 6 "$@" 2>/dev/null || true; }

echo "booting provider-ih, consumer-ih, issuer, bdrs on $NET ..."
boot_ih provider 7084; boot_ih consumer 7086; boot_issuer; boot_bdrs

out="$K2/env/identity-smoke.csv"; echo "group,check,expected,got,ok,jar_sha256,commit" > "$out"
row(){ local ok=no; [ "$3" = "$4" ] && ok=yes; echo "$1,$2,$3,$4,$ok,$IHSHA,$COMMIT" >> "$out"; echo "$1/$2 expected=$3 got=$4 ok=$ok"; }

ready pilot08k2-provider-ih "seeded participant 'provider'" && pv=ready || pv=notready
ready pilot08k2-consumer-ih "seeded participant 'consumer'" && cv=ready || cv=notready
ready pilot08k2-issuer " ready" && iv=ready || iv=notready
ready pilot08k2-bdrs " ready" && bv=ready || bv=notready
row readiness provider_ih_seeded ready "$pv"
row readiness consumer_ih_seeded ready "$cv"
row readiness issuer_booted ready "$iv"
row readiness bdrs_booted ready "$bv"

PDID="did:web:provider-ih%3A7084:provider"; CDID="did:web:consumer-ih%3A7086:consumer"
PURL="http://provider-ih:7084/provider/did.json"; CURL="http://consumer-ih:7086/consumer/did.json"
# R2: REAL cross-resolution — consumer-ih fetches the PROVIDER DID, provider-ih fetches the CONSUMER DID
row crossres consumer_ih_fetches_provider_did 200 "$(inhc pilot08k2-consumer-ih "$PURL")"
row crossres provider_ih_fetches_consumer_did 200 "$(inhc pilot08k2-provider-ih "$CURL")"
# id must equal the configured DID, and the document must carry an Ed25519 public key
pbody="$(inbody pilot08k2-consumer-ih "$PURL")"; cbody="$(inbody pilot08k2-provider-ih "$CURL")"
row crossres provider_did_id_match "$PDID" "$(echo "$pbody" | "$JQ" -r '.id' 2>/dev/null)"
row crossres consumer_did_id_match "$CDID" "$(echo "$cbody" | "$JQ" -r '.id' 2>/dev/null)"
row crossres provider_vm_Ed25519 Ed25519 "$(echo "$pbody" | "$JQ" -r '.verificationMethod[0].publicKeyJwk.crv' 2>/dev/null)"
row crossres consumer_vm_Ed25519 Ed25519 "$(echo "$cbody" | "$JQ" -r '.verificationMethod[0].publicKeyJwk.crv' 2>/dev/null)"
# R2: no PRIVATE key material leaked into a DID document (JWK must have no "d" member)
pd="$(echo "$pbody" | "$JQ" -r '[.verificationMethod[].publicKeyJwk.d // empty]|length' 2>/dev/null)"
cd_="$(echo "$cbody" | "$JQ" -r '[.verificationMethod[].publicKeyJwk.d // empty]|length' 2>/dev/null)"
row crossres provider_no_private_member 0 "${pd:-NA}"
row crossres consumer_no_private_member 0 "${cd_:-NA}"
echo "---"; cat "$out"
