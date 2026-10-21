#!/usr/bin/env bash
# Boot smoke checks for the running rung, driven from inside the internal network
# (the network is internal, so no host ports; the harness uses a driver container).
# These are testbed sanity checks, not invariant results. Appends to env/boot-smoke.csv.
source "$(dirname "$0")/lib.sh"
TX_TAG="${1:?usage: 21_smoke.sh <tx_tag>}"
out="$PILOT/env/boot-smoke.csv"
[ -f "$out" ] || echo "tx_tag,check,expected,got,ok,commit" > "$out"
row() { ok=no; [ "$2" = "$3" ] && ok=yes; echo "$TX_TAG,$1,$2,$3,$ok,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
code() { drv -s -o /dev/null -w '%{http_code}' "$@"; }
Q='{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"QuerySpec"}'
DSP='{"@context":{"dspace":"https://w3id.org/dspace/v0.8/"},"@type":"dspace:CatalogRequestMessage"}'
row health_200             200 "$(code http://provider:8080/api/check/health)"
row mgmt_nokey_401         401 "$(code -X POST http://provider:8181/management/v3/assets/request -H 'Content-Type: application/json' -d "$Q")"
row mgmt_key_200           200 "$(code -X POST http://provider:8181/management/v3/assets/request -H 'Content-Type: application/json' -H 'X-Api-Key: pilot08-provider-mgmt' -d "$Q")"
row dsp_catalog_noauth_401 401 "$(code -X POST http://provider:8282/api/v1/dsp/catalog/request -H 'Content-Type: application/json' -d "$DSP")"
# A bogus bearer token is also rejected (the DSP endpoint demands a valid DCP token, not just any header).
row dsp_catalog_fakebearer_401 401 "$(code -X POST http://provider:8282/api/v1/dsp/catalog/request -H 'Content-Type: application/json' -H 'Authorization: faketoken' -d "$DSP")"
