#!/usr/bin/env bash
# KC2 step 3 — DSP-TCK baseline (D14, Option A): run the official DSP TCK the way upstream does — against a
# TCK-configured connector-under-test ("cut") with the TCK's static mock-identity header, NOT through DCP.
# Local testbed only: own internal network pilot08k2_tck (no egress, no host ports).
#   vanilla  : EDC v0.18.1 dsp-tck-connector-under-test reproduced (kc2/vanilla, -Prole=tck), upstream config
#              from system-tests/tck/dsp-tck-tests/DspTckDockerTest.
#   tractusx : the Tractus-X 0.13.0 RELEASE IMAGE binary + thin add-on jar (tck-extension 0.17.0 + the four
#              upstream test stand-ins, kc2/tck-tx), upstream config from EdcCompatibilityPostgresTest.
# TCK configuration: kc2/tck/<target>/ (upstream copies). Results: kc2/env/tck-dsp-<target>.csv (per test)
# + raw TCK output kc2/env/tck-dsp-<target>.txt. Conformance on public specs — tracked (not a finding).
# Usage: ./50_tck_baseline.sh vanilla|tractusx
source "$(dirname "$0")/../../scripts/lib.sh"
T="${1:?usage: 50_tck_baseline.sh vanilla|tractusx}"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
TCK_DIGEST="sha256:f5f7fcc80f607dad680f363ba32f9abf6762aa9c4f54a2a211f6fec2582730fd"   # dsp-tck-runtime:1.0.2
TCK_IMG="eclipsedataspacetck/dsp-tck-runtime@$TCK_DIGEST"; TCK_VER="1.0.2"
TX_IMG="pilot08k2/edc-runtime-memory:0.13.0"
NET="pilot08k2_tck"; S="$PILOT/testbed/.secrets/kc2"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08k2-cut pilot08k2-tck >/dev/null 2>&1
run="$PILOT/build/kc2-tck-$T"; rm -rf "$run"; mkdir -p "$run"

case "$T" in
  vanilla)
    JAR="$PILOT/kc2/vanilla/build/libs/pilot08kc2-vanilla-tck-0.18.1.jar"
    [ -f "$JAR" ] || { echo "missing $JAR — run ROLE=tck kc2/scripts/11_build_vanilla.sh"; exit 1; }
    SHA="$(sha256sum "$JAR" | cut -d' ' -f1)"
    grep -qE "^vanilla-0.18.1,$SHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/tck-jars.csv" 2>/dev/null || { echo "tck jar $SHA not recorded at a clean commit"; exit 1; }
    BIN="vanilla-tck-jar:$SHA"; cp "$JAR" "$run/app.jar"
    cat > "$run/cfg.properties" <<EOF
edc.participant.id=participantContextId
web.http.port=8080
web.http.path=/api
web.http.management.port=8081
web.http.management.path=/api/management
web.http.protocol.port=8282
web.http.protocol.path=/api/dsp
web.api.auth.key=password
edc.dsp.callback.address=http://cut:8282/api/dsp
edc.hostname=cut
edc.component.id=DSP-compatibility-test
EOF
    MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-cut --network "$NET" --network-alias cut -v "$run":/work -w /work \
      "$GRADLE_IMG" java -Dedc.fs.config=/work/cfg.properties -jar /work/app.jar >/dev/null 2>&1 ;;
  tractusx)
    ADDON="$PILOT/kc2/tck-tx/build/libs/pilot08kc2-tck-tx-addon.jar"
    [ -f "$ADDON" ] || { echo "missing $ADDON — run ROLE=tck-tx kc2/scripts/11_build_vanilla.sh"; exit 1; }
    SHA="$(sha256sum "$ADDON" | cut -d' ' -f1)"
    grep -qE "^tractusx-0.13.0-addon,$SHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/tck-jars.csv" 2>/dev/null || { echo "addon jar $SHA not recorded at a clean commit"; exit 1; }
    DIG="$(docker image inspect "$TX_IMG" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"; BIN="tx-image:$DIG+addon:$SHA"
    cp "$ADDON" "$run/addon.jar"
    BPN="BPNL0000participantContextId"
    sp="$(cat "$S/provider-signer.priv.jwk")"; pp="$(cat "$S/provider-signer.pub.jwk")"
    cat > "$run/cfg.properties" <<EOF
edc.participant.id=$BPN
edc.participant.context.id=participantContextId
web.http.port=8080
web.http.path=/api
web.http.control.port=8083
web.http.control.path=/control
web.http.management.port=8081
web.http.management.path=/management
web.http.protocol.port=8282
web.http.protocol.path=/protocol
web.http.tck.port=8687
web.http.tck.path=/tck
web.api.auth.key=password
edc.dsp.callback.address=http://cut:8282/protocol
edc.management.context.enabled=true
edc.hostname=cut
edc.component.id=DSP-tck-test
edc.transfer.proxy.token.signer.privatekey.alias=private-key
edc.transfer.proxy.token.verifier.publickey.alias=public-key
edc.policy.validation.enabled=true
edc.iam.issuer.id=did:web:participantContextId
edc.iam.sts.oauth.token.url=http://sts.example.com/token
edc.iam.sts.oauth.client.id=$BPN
edc.iam.sts.oauth.client.secret.alias=test-clientid-alias
tx.edc.iam.dcp.bdrs.server.url=http://sts.example.com
web.http.management.auth.key=password
tx.edc.dpf.consumer.proxy.port=8186
tx.edc.dpf.consumer.proxy.auth.apikey=password
edc.transfer.send.retry.limit=3
edc.transfer.send.retry.base-delay.ms=100
tx.edc.dataplane.token.expiry=3
tx.edc.dataplane.token.expiry.tolerance=0
web.http.public.path=/public
web.http.public.port=8185
edc.dataplane.api.public.baseurl=http://cut:8185/public/v2/data
tractusx.edc.participant.bpn=$BPN
pilot08.kc2.tck.bpn=$BPN
EOF
    MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-cut --network "$NET" --network-alias cut -v "$run":/work -w /app \
      -e TX_EDC_VAULT_SECRETS="private-key:$sp;public-key:$pp;test-clientid-alias:unused" -e OTEL_JAVAAGENT_ENABLED=false \
      --entrypoint java "$TX_IMG" -Dedc.fs.config=/work/cfg.properties -cp /app/edc-runtime.jar:/work/addon.jar \
      org.eclipse.edc.boot.system.runtime.BaseRuntime >/dev/null 2>&1 ;;
  *) echo "unknown target $T"; exit 2;;
esac

for _ in $(seq 1 90); do docker logs pilot08k2-cut 2>&1 | grep -qE ' ready| SEVERE ' && break; done
docker logs pilot08k2-cut 2>&1 | grep -q ' ready' || { echo "connector-under-test not ready"; docker logs pilot08k2-cut 2>&1 | grep -E "SEVERE|ERROR" | head -15; exit 4; }
echo "== cut ready; service replacements (which provider won) =="
docker logs pilot08k2-cut 2>&1 | grep -oE "A service of the type [^ ]+ was already registered and has now been replaced with a [A-Za-z0-9$]+ instance" | sed 's/A service of the type //' | sort -u | tee "$run/replacements.txt" || true

echo "== TCK $TCK_VER =="
MSYS_NO_PATHCONV=1 docker run -d --name pilot08k2-tck --network "$NET" --network-alias tck \
  -v "$PILOT/kc2/tck/$T":/etc/tck:ro "$TCK_IMG" >/dev/null 2>&1
for _ in $(seq 1 400); do docker logs pilot08k2-tck 2>&1 | grep -qE 'Test run complete' && break; docker ps -q --filter name=pilot08k2-tck | grep -q . || break; done
raw="$PILOT/kc2/env/tck-dsp-$T.txt"; docker logs pilot08k2-tck > "$raw" 2>&1
grep -qE 'Test run complete' "$raw" || { echo "TCK did not complete — see $raw"; tail -20 "$raw"; exit 5; }
echo "--- TCK summary lines ---"; grep -iE "Test run complete|tests? (succeeded|failed|passed)|Tests found|FAILED:" "$raw" | head -40 || true
echo "(target=$T bin=$BIN tck=$TCK_VER commit=$COMMIT)"
