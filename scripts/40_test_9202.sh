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
alice_sees=no; echo "$alice_cat" | grep -q "$ASSET" && alice_sees=yes
mallory_sees_catalog=no; echo "$mallory_cat" | grep -q "$ASSET" && mallory_sees_catalog=yes
mallory_ds_code="$(ds_as mallory)"
# Leak = the single-dataset endpoint actually RETURNS the dataset to the denied party.
# Key off HTTP 200 + a real dcat:Dataset body; a 404 "not found" body also echoes the
# asset id, so a plain id grep would false-positive on the patched (blocked) rung.
mallory_ds_leak=no
[ "$mallory_ds_code" = 200 ] && echo "$(ds_body mallory)" | grep -q 'dcat:Dataset' && mallory_ds_leak=yes

# --- oracle ---
# precondition (fixture works): alice sees it, mallory does NOT see it in the full catalogue.
# vuln present (FAIL) iff mallory can still fetch it via the single-dataset endpoint.
verdict=INVALID
if [ "$alice_sees" = yes ] && [ "$mallory_sees_catalog" = no ]; then
  [ "$mallory_ds_leak" = yes ] && verdict=FAIL || verdict=PASS
fi
out="$PILOT/results/cve-2024-9202.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,test,alice_sees_catalog,mallory_sees_catalog,mallory_dataset_http,mallory_dataset_leak,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,cve-2024-9202,$alice_sees,$mallory_sees_catalog,$mallory_ds_code,$mallory_ds_leak,$verdict,$sha,$COMMIT" >> "$out"
echo "$V: alice_sees=$alice_sees mallory_catalog=$mallory_sees_catalog mallory_dataset_http=$mallory_ds_code leak=$mallory_ds_leak => $verdict"
