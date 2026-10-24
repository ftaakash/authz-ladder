#!/usr/bin/env bash
# CVE-2024-9202 regression test — single-dataset request bypasses catalogue policy.
# Invariant: a dataset hidden from a counterparty in the full catalogue must also be
# unavailable to that counterparty via the single-dataset DSP endpoint.
# Oracle: FAIL on affected builds (leak), PASS on the patched build (no leak).
# Admitted only if the full vanilla ladder reads FAIL/FAIL/FAIL/PASS across
# 0.6.2/0.6.3/0.9.0/0.9.1 (fix lands at 0.9.1); any non-2xx seed or failed
# precondition yields INVALID (see invalid_reason), which does not admit the test.
# Usage: ./40_test_9202.sh 0.9.0   (rung must be built; boots it on pilot08v)
source "$(dirname "$0")/lib.sh"
V="${1:?usage: 40_test_9202.sh <edc-version>}"
NET="pilot08v"; MK="pilot08-provider-mgmt"; ASSET="asset-9202"
# sha of the jar actually run; append-only vanilla-jars.csv may hold several rows per version,
# so verify this exact sha is recorded rather than grabbing the first row.
sha="$(sha256sum "$PILOT/testbed/launcher/build/libs/pilot08-edc-$V.jar" 2>/dev/null | cut -d' ' -f1)"
grep -qE "^$V,$sha,[0-9]+,[0-9a-f]{7}," "$PILOT/env/vanilla-jars.csv" 2>/dev/null || { echo "jar sha $sha for $V not recorded at a clean commit — rebuild"; exit 1; }
# Boot via 31; keep its diagnostics so a boot failure shows the real reason (not a bare "boot failed").
bootlog="$(bash "$PILOT/scripts/31_run_vanilla.sh" "$V" 2>&1)" || { echo "boot failed for $V:"; printf '%s\n' "$bootlog" | tail -5; exit 1; }
# Management API version per resource: assets is /v3 on every rung, but policy &
# contract definitions are /v2 on the 0.6.x line (the bundled management-api exposes
# v2 there; v3 for those arrived later) and /v3 on 0.9.x. Wrong version -> 404 seed.
case "$V" in 0.6*) PV=v2 ;; *) PV=v3 ;; esac
mdrv() { docker run --rm --network "$NET" "$DRIVER_IMG" -s -w '\n%{http_code}' --max-time 8 "$@" 2>/dev/null; }
mgmt() { mdrv -X POST "http://provider:8181/management/$1/$2" -H 'Content-Type: application/json' -H "X-Api-Key: $MK" -d "$3"; }

# --- seed: asset + access policy (admit only alice) + contract definition ---
# Capture each POST's HTTP code so the record shows whether seeding succeeded per rung.
code_of() { tail -1 <<<"$1"; }
seed_asset="$(code_of "$(mgmt v3 assets '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"'"$ASSET"'","properties":{"name":"restricted"},"dataAddress":{"@type":"DataAddress","type":"HttpData","baseUrl":"http://sink:9/x"}}')")"
seed_policy="$(code_of "$(mgmt $PV policydefinitions '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"pol-alice","policy":{"@context":["http://www.w3.org/ns/odrl.jsonld",{"pilot08":"https://pilot08.test/ns/"}],"@type":"Set","permission":[{"action":"use","constraint":[{"leftOperand":"pilot08:participant","operator":"eq","rightOperand":"alice"}]}]}}')")"
seed_cd="$(code_of "$(mgmt $PV contractdefinitions '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"cd-9202","accessPolicyId":"pol-alice","contractPolicyId":"pol-alice","assetsSelector":[{"@type":"Criterion","operandLeft":"https://w3id.org/edc/v0.0.1/ns/id","operator":"=","operandRight":"'"$ASSET"'"}]}')")"
echo "seed codes ($PV): asset=$seed_asset policy=$seed_policy cd=$seed_cd"

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
verdict=INVALID; invalid_reason=""
is2xx() { case "$1" in 2??) return 0;; *) return 1;; esac; }
if ! is2xx "$seed_asset" || ! is2xx "$seed_policy" || ! is2xx "$seed_cd"; then
  invalid_reason="seed-failed(asset=$seed_asset,policy=$seed_policy,cd=$seed_cd)"
elif [ "$alice_cat_ok" != yes ] || [ "$mallory_cat_ok" != yes ]; then
  invalid_reason="catalogue-not-200"
elif [ "$alice_sees" != yes ] || [ "$mallory_sees_catalog" != no ]; then
  invalid_reason="fixture-not-discriminating(aliceSees=$alice_sees,mallorySees=$mallory_sees_catalog)"
elif [ "$alice_ds_leak" != yes ]; then
  invalid_reason="positive-control-failed(alice cannot fetch dataset)"
else
  [ "$mallory_ds_leak" = yes ] && verdict=FAIL || verdict=PASS
fi
# results/: SCOPE columns only (version, invariant, verdict, commit, jar sha). Observations go to env/.
out="$PILOT/results/cve-2024-9202.csv"; mkdir -p "$PILOT/results"
[ -f "$out" ] || echo "edc_version,invariant,verdict,jar_sha256,commit" > "$out"
grep -v "^$V," "$out" > "$out.tmp" 2>/dev/null; mv "$out.tmp" "$out"
echo "$V,catalogue-visibility(CVE-2024-9202),$verdict,$sha,$COMMIT" >> "$out"
# observations keyed by version+commit+jar_sha256 so each row joins to its result row (M2).
obs="$PILOT/env/cve-2024-9202-observations.csv"
[ -f "$obs" ] || echo "edc_version,jar_sha256,commit,seed_asset,seed_policy,seed_cd,alice_cat_200,mallory_cat_200,alice_sees,mallory_sees_catalog,alice_dataset_http,alice_dataset_leak,mallory_dataset_http,mallory_dataset_leak,verdict,invalid_reason" > "$obs"
grep -v "^$V," "$obs" > "$obs.tmp" 2>/dev/null; mv "$obs.tmp" "$obs"
echo "$V,$sha,$COMMIT,$seed_asset,$seed_policy,$seed_cd,$alice_cat_ok,$mallory_cat_ok,$alice_sees,$mallory_sees_catalog,$alice_ds_code,$alice_ds_leak,$mallory_ds_code,$mallory_ds_leak,$verdict,$invalid_reason" >> "$obs"
echo "$V: aliceCat=$alice_cat_ok malCat=$mallory_cat_ok aliceSees=$alice_sees malSees=$mallory_sees_catalog aliceDS=$alice_ds_code/$alice_ds_leak malDS=$mallory_ds_code/$mallory_ds_leak => $verdict"
