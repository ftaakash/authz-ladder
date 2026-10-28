#!/usr/bin/env bash
# KC2 step 3 (U5) — DCP-TCK presentation-flow baseline against the shared 0.17.0 IdentityHub (D12), reproducing
# eclipse-edc/IdentityHub v0.17.0 DcpPresentationFlowWithDockerTest. Local testbed only, internal network
# pilot08k2_tck. The holder IdentityHub (kc2/tck-ih) seeds one holder participant + credential request and
# provides the TCK scope transformer; the DCP TCK (eclipsedataspacetck/dcp-tck-runtime, by digest) runs the
# credential-service verification package. DEVIATION (TCK-PLAN): RevocationServiceRegistry is real, not mocked.
# Results: kc2/env/tck-dcp-identityhub.csv (+ raw .txt). Conformance on public specs — tracked, not a finding.
# Usage: ./51_tck_dcp.sh
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
# DCP TCK line upstream paired with IdentityHub 0.17.0 (its docker test pins 1.0.0-RC5). 1.2.1 vs 0.17.0 was a
# forward mismatch — every scenario failed in the TCK's credential-seeding step ("Bad Request"/"Conflict") — discarded.
DCP_TCK_DIGEST="sha256:02c298a2a223c63cf0f68cebbccf004bbf5def9abb7fbe89477ae8e04b788c6a"; DCP_TCK_VER="1.0.0"
NET="pilot08k2_tck"; S="$PILOT/testbed/.secrets/kc2"
JAR="$PILOT/kc2/tck-ih/build/libs/pilot08kc2-tck-ih-0.17.0.jar"
[ -f "$JAR" ] || { echo "missing $JAR — run ROLE=tck-ih kc2/scripts/11_build_vanilla.sh"; exit 1; }
SHA="$(sha256sum "$JAR" | cut -d' ' -f1)"
grep -qE "^tck-ih-0.17.0,$SHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/tck-jars.csv" 2>/dev/null || { echo "tck-ih jar $SHA not recorded at a clean commit"; exit 1; }
DIDPORT=7084; CREDPORT=7082; STSPORT=7083
HOLDER_DID="did:web:tck-ih%3A$DIDPORT:holder"
CS_URL="http://tck-ih:$CREDPORT/api/credentials/v1/participants/holder"
CORRELATION="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo 11111111-1111-1111-1111-111111111111)"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08k2-tck-ih pilot08k2-dcptck >/dev/null 2>&1
run="$PILOT/build/kc2-tck-ih"; rm -rf "$run"; mkdir -p "$run"; cp "$JAR" "$run/app.jar"; cp "$S/holder.priv.jwk" "$run/holder.priv.jwk"
cat > "$run/cfg.properties" <<EOF
web.http.port=7080
web.http.path=/api
web.http.identity.port=7081
web.http.identity.path=/api/identity
web.http.credentials.port=$CREDPORT
web.http.credentials.path=/api/credentials
web.http.sts.port=$STSPORT
web.http.sts.path=/api/sts
web.http.did.port=$DIDPORT
web.http.did.path=/
edc.iam.did.web.use.https=false
edc.iam.accesstoken.jti.validation=true
edc.iam.sts.publickey.id=test-public-key
edc.iam.sts.privatekey.alias=holder-privatekey-alias
edc.encryption.aes.key.alias=aes-encryption-key
edc.encryption.strict=false
pilot08.kc2.tckih.participant=holder
pilot08.kc2.tckih.did=$HOLDER_DID
pilot08.kc2.tckih.holderjwk.path=/work/holder.priv.jwk
pilot08.kc2.tckih.credentialservice.url=$CS_URL
pilot08.kc2.tckih.correlation.id=$CORRELATION
pilot08.kc2.tckih.sts.out=/work/tck-sts.json
EOF
MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-tck-ih --network "$NET" --network-alias tck-ih -v "$run":/work -w /work \
  "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/app.jar ${CONN_ARGS:-} >/dev/null 2>&1
for _ in $(seq 1 90); do docker logs pilot08k2-tck-ih 2>&1 | grep -qE "seeded holder|SEVERE|seeding failed" && break; done
docker logs pilot08k2-tck-ih 2>&1 | grep -qE "seeded holder 'holder'" || { echo "holder IdentityHub not seeded"; docker logs pilot08k2-tck-ih 2>&1 | grep -iE "pilot08-kc2-tckih|SEVERE" | tail -10; exit 4; }
[ -f "$run/tck-sts.json" ] || { echo "no tck-sts.json written"; exit 4; }
CID="$("$JQ" -r .clientId "$run/tck-sts.json")"; CSECRET="$("$JQ" -r .clientSecret "$run/tck-sts.json")"
echo "holder seeded; did=$HOLDER_DID clientId=$CID"
# did:web resolves?
echo "holder did.json: $(docker run --rm --network "$NET" pilot08/curl:8.11.1 -s -o /dev/null -w '%{http_code}' --max-time 8 http://tck-ih:$DIDPORT/holder/did.json)"

echo "== DCP TCK $DCP_TCK_VER (presentation.cs) =="
MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-dcptck --network "$NET" --network-alias tck --network-alias issuer \
  -e dataspacetck.callback.address="http://tck:8083" -e dataspacetck.host=0.0.0.0 -e dataspacetck.port=8083 \
  -e dataspacetck.launcher=org.eclipse.dataspacetck.dcp.system.DcpSystemLauncher \
  -e dataspacetck.did.holder="$HOLDER_DID" \
  -e dataspacetck.sts.url="http://tck-ih:$STSPORT/api/sts" \
  -e dataspacetck.sts.client.id="$CID" -e dataspacetck.sts.client.secret="$CSECRET" \
  -e dataspacetck.credentials.correlation.id="$CORRELATION" \
  -e dataspacetck.test.package="org.eclipse.dataspacetck.dcp.verification.presentation.cs" \
  "eclipsedataspacetck/dcp-tck-runtime@$DCP_TCK_DIGEST" >/dev/null 2>&1
timeout 600 docker logs -f pilot08k2-dcptck 2>&1 | grep -m1 -qiE 'test run complete' || true
raw="$PILOT/kc2/env/tck-dcp-identityhub.txt"; docker logs pilot08k2-dcptck > "$raw" 2>&1
grep -qiE 'test run complete' "$raw" || { echo "DCP TCK did not complete — see $raw"; tail -25 "$raw"; exit 5; }
echo "--- DCP TCK summary ---"; grep -iE "test run complete|there were failing tests|passed|failed|FAILED:" "$raw" | head -40 || true
echo "(holder_ih_jar=$SHA dcp_tck=$DCP_TCK_VER commit=$COMMIT)"
