#!/usr/bin/env bash
# Boot one vanilla-EDC rung as a provider on an internal network and smoke it.
# Proves the SUT runs and that an iam-mock counterparty can reach the DSP layer.
# Records env/vanilla-smoke.csv (testbed sanity, not CVE results).
# Usage: ./31_run_vanilla.sh 0.6.2   (jar must be built: scripts/30_build_vanilla.sh <v>)
source "$(dirname "$0")/lib.sh"
V="${1:?usage: 31_run_vanilla.sh <edc-version>}"
IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"  # JRE carrier (build image reused); logged in ENV.md
NET="pilot08v"   # internal network for the vanilla KC1 SUT (separate from KC2's pilot08_dsp)
# Run the version-specific jar (not the generic -all.jar, which is whatever was built last).
jar="$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar"
[ -f "$jar" ] || { echo "no jar for $V — run scripts/30_build_vanilla.sh $V first"; exit 1; }
# Verify this jar's sha256 is recorded at a CLEAN commit before booting. vanilla-jars.csv is
# append-only (several rows per version), so match the exact (version,sha,size,clean-commit) row
# with a regex — never compare against a multi-line `grep|cut` capture, which is always "unequal".
got="$(sha256sum "$jar" | cut -d' ' -f1)"
grep -qE "^$V,$got,[0-9]+,[0-9a-f]{7}," "$PILOT/env/vanilla-jars.csv" 2>/dev/null \
  || { echo "jar sha $got for $V not recorded at a clean commit — rebuild on a clean tree"; exit 1; }
export RUN_SHA="$got"
run="$PILOT/build/run"; mkdir -p "$run"; cp "$jar" "$run/app.jar"; cp "$PILOT/testbed/launcher/config/provider.properties" "$run/"
docker network inspect "$NET" >/dev/null 2>&1 || docker network create --internal "$NET" >/dev/null
docker rm -f pilot08v-provider >/dev/null 2>&1
MSYS_NO_PATHCONV=1 docker run -d --name pilot08v-provider --network "$NET" --network-alias provider \
  -v "$run":/work -w /work "$IMG" java -Dedc.fs.config=/work/provider.properties -jar /work/app.jar >/dev/null 2>&1
for _ in $(seq 1 45); do docker logs pilot08v-provider 2>&1 | grep -q ' ready' && break; sleep 2; done
docker logs pilot08v-provider 2>&1 | grep -q ' ready' || { echo "provider not ready on $V"; docker logs pilot08v-provider 2>&1 | tail -20; exit 1; }

out="$PILOT/env/vanilla-smoke.csv"; [ -f "$out" ] || echo "edc_version,check,expected,got,ok,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"   # one run per version
drvn() { docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null -w '%{http_code}' --max-time 6 "$@" 2>/dev/null; }
row() { ok=no; [ "$2" = "$3" ] && ok=yes; echo "$V,$1,$2,$3,$ok,$RUN_SHA,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
# D3: the KC1 SUT network must be internal (local-only), like pilot08_dsp for KC2.
row net_internal true "$(docker network inspect "$NET" --format '{{.Internal}}')"
Q='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}'
DSP='{"@context":{"dspace":"https://w3id.org/dspace/v0.8/"},"@type":"dspace:CatalogRequestMessage","dspace:filter":{}}'
TOK='{"region":"eu","clientId":"consumer","audience":"provider"}'
row health_200              200 "$(drvn http://provider:8080/api/check/health)"
# F5: management API must require the api key (setup calls use it; assertions never touch :8181).
row mgmt_nokey_401          401 "$(drvn -X POST http://provider:8181/management/v3/assets/request -H 'Content-Type: application/json' -d "$Q")"
row mgmt_key_200            200 "$(drvn -X POST http://provider:8181/management/v3/assets/request -H 'Content-Type: application/json' -H 'X-Api-Key: pilot08-provider-mgmt' -d "$Q")"
row dsp_catalog_noauth_401  401 "$(drvn -X POST http://provider:8282/api/v1/dsp/catalog/request -H 'Content-Type: application/json' -d "$DSP")"
row dsp_catalog_mocktoken_200 200 "$(drvn -X POST http://provider:8282/api/v1/dsp/catalog/request -H 'Content-Type: application/json' -H "Authorization: $TOK" -d "$DSP")"
