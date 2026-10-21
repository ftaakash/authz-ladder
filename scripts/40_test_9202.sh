#!/usr/bin/env bash
# CVE-2024-9202 regression test — single-dataset request bypasses catalogue policy.
# Invariant: a dataset hidden from a counterparty in the full catalogue must also be
# unavailable to that counterparty via the single-dataset DSP endpoint.
# Oracle: FAIL on the affected build (leak), PASS on the patched build (no leak).
# Admitted only if it flips FAIL->PASS at 0.9.0 -> 0.9.1.
# Usage: ./40_test_9202.sh 0.9.0   (rung must be built; boots it on pilot08v)
source "$(dirname "$0")/lib.sh"
V="${1:?usage: 40_test_9202.sh <edc-version>}"
NET="pilot08v"; MK="pilot08-provider-mgmt"; ASSET="asset-9202"
bash "$PILOT/scripts/31_run_vanilla.sh" "$V" >/dev/null 2>&1 || { echo "boot failed"; exit 1; }
sha="$(grep "^$V," "$PILOT/env/vanilla-jars.csv" | cut -d, -f2)"
mdrv() { docker run --rm --network "$NET" "$DRIVER_IMG" -s -w '\n%{http_code}' --max-time 8 "$@" 2>/dev/null; }
mgmt() { mdrv -X POST "http://provider:8181/management/v3/$1" -H 'Content-Type: application/json' -H "X-Api-Key: $MK" -d "$2"; }

# --- seed: asset + access policy (admit only alice) + contract definition ---
mgmt assets '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"'"$ASSET"'","properties":{"name":"restricted"},"dataAddress":{"@type":"DataAddress","type":"HttpData","baseUrl":"http://sink:9/x"}}' >/dev/null
mgmt policydefinitions '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"pol-alice","policy":{"@context":["http://www.w3.org/ns/odrl.jsonld",{"pilot08":"https://pilot08.test/ns/"}],"@type":"Set","permission":[{"action":"use","constraint":[{"leftOperand":"pilot08:participant","operator":"eq","rightOperand":"alice"}]}]}}' >/dev/null
mgmt contractdefinitions '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"cd-9202","accessPolicyId":"pol-alice","contractPolicyId":"pol-alice","assetsSelector":[{"@type":"Criterion","operandLeft":"https://w3id.org/edc/v0.0.1/ns/id","operator":"=","operandRight":"'"$ASSET"'"}]}' >/dev/null

# --- DSP queries as alice (admitted) and mallory (denied) ---
CAT='{"@context":{"dspace":"https://w3id.org/dspace/v0.8/"},"@type":"dspace:CatalogRequestMessage","dspace:filter":{}}'
tok() { echo '{"region":"eu","clientId":"'"$1"'","audience":"provider"}'; }
cat_as() { docker run --rm --network "$NET" "$DRIVER_IMG" -s --max-time 8 -X POST http://provider:8282/api/v1/dsp/catalog/request -H 'Content-Type: application/json' -H "Authorization: $(tok "$1")" -d "$CAT" 2>/dev/null; }
ds_as()  { docker run --rm --network "$NET" "$DRIVER_IMG" -s -o /dev/null -w '%{http_code}' --max-time 8 http://provider:8282/api/v1/dsp/catalog/datasets/"$ASSET" -H "Authorization: $(tok "$1")" 2>/dev/null; }
ds_body(){ docker run --rm --network "$NET" "$DRIVER_IMG" -s --max-time 8 http://provider:8282/api/v1/dsp/catalog/datasets/"$ASSET" -H "Authorization: $(tok "$1")" 2>/dev/null; }

alice_cat="$(cat_as alice)"; mallory_cat="$(cat_as mallory)"
# catalogue validity: a real 200 dcat:Catalog (else the request errored and "hidden" is meaningless, M1)
alice_cat_ok=no;   echo "$alice_cat"   | grep -q 'dcat:Catalog' && alice_cat_ok=yes
mallory_cat_ok=no; echo "$mallory_cat" | grep -q 'dcat:Catalog' && mallory_cat_ok=yes
alice_sees=no;            echo "$alice_cat"   | grep -q "$ASSET" && alice_sees=yes
mallory_sees_catalog=no;  echo "$mallory_cat" | grep -q "$ASSET" && mallory_sees_catalog=yes
# single-dataset endpoint: leak iff HTTP 200 + a real dcat:Dataset body (a 404 body also echoes the id).
alice_ds_code="$(ds_as alice)";   alice_ds_leak=no;   [ "$alice_ds_code" = 200 ] && echo "$(ds_body alice)"   | grep -q 'dcat:Dataset' && alice_ds_leak=yes
mallory_ds_code="$(ds_as mallory)"; mallory_ds_leak=no; [ "$mallory_ds_code" = 200 ] && echo "$(ds_body mallory)" | grep -q 'dcat:Dataset' && mallory_ds_leak=yes

# --- oracle ---
# Preconditions (else INVALID, not a CVE signal):
#   both catalogues return 200 dcat:Catalog; alice sees the asset; mallory does NOT (fixture discriminates);
#   positive control: alice CAN fetch it via the single-dataset endpoint on this rung (so a mallory 404 is a real block).
# Given those, the CVE is present (FAIL) iff mallory can still fetch the hidden dataset via the endpoint.
verdict=INVALID
if [ "$alice_cat_ok" = yes ] && [ "$mallory_cat_ok" = yes ] \
   && [ "$alice_sees" = yes ] && [ "$mallory_sees_catalog" = no ] && [ "$alice_ds_leak" = yes ]; then
  [ "$mallory_ds_leak" = yes ] && verdict=FAIL || verdict=PASS
fi
# results/: SCOPE columns only (version, invariant, verdict, commit, jar sha). Observations go to env/.
out="$PILOT/results/cve-2024-9202.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,invariant,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,catalogue-visibility(CVE-2024-9202),$verdict,$sha,$COMMIT" >> "$out"
obs="$PILOT/env/9202-observations.csv"
[ -f "$obs" ] || echo "edc_version,alice_cat_200,mallory_cat_200,alice_sees,mallory_sees_catalog,alice_dataset_http,alice_dataset_leak,mallory_dataset_http,mallory_dataset_leak,verdict,commit" > "$obs"
grep -v "^$V," "$obs" > "$obs.tmp" 2>/dev/null; mv "$obs.tmp" "$obs"
echo "$V,$alice_cat_ok,$mallory_cat_ok,$alice_sees,$mallory_sees_catalog,$alice_ds_code,$alice_ds_leak,$mallory_ds_code,$mallory_ds_leak,$verdict,$COMMIT" >> "$obs"
echo "$V: aliceCat=$alice_cat_ok malCat=$mallory_cat_ok aliceSees=$alice_sees malSees=$mallory_sees_catalog aliceDS=$alice_ds_code/$alice_ds_leak malDS=$mallory_ds_code/$mallory_ds_leak => $verdict"
