#!/usr/bin/env bash
# KC2 step 2 — DCP handshake bring-up (local testbed only, internal network).
# Stack: issuer did:web server; provider, consumer and third participants, each with its own
# IdentityHub 0.17.0 (participant + MembershipCredential signed by the TRUSTED issuer); BDRS seeded
# BPN->DID; Tractus-X 0.13.0 connectors. Records INFRASTRUCTURE rows only (Review 13 S3) in
# kc2/env/handshake-smoke.csv: readiness, BDRS seeding, the no-token DSP refusal baseline, and the
# DCP-authenticated catalogue with the trusted issuer (positive control). No invariant assertion runs here.
# Usage: ./40_up_handshake.sh          (CONN_ARGS=--log-level=DEBUG for connector debug logs)
source "$(dirname "$0")/handshake_lib.sh"

# Jar guard (KC1 style): the IdentityHub jar must be recorded at a CLEAN commit in identity-jars.csv.
IHSHA="$(sha256sum "$IHJAR" | cut -d' ' -f1)"
grep -qE "^identityhub,[0-9.]+,$IHSHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/identity-jars.csv" 2>/dev/null \
  || { echo "IdentityHub jar sha $IHSHA not recorded at a clean commit — run 10_build_identity.sh on a clean tree"; exit 1; }
CONN_DIGEST="$(docker image inspect "$CONN_IMG" --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//')"

# participants: id didport bpn
PARTS="provider:7084:BPNL000000PROVIDER consumer:7086:BPNL000000CONSUMER third:7088:BPNL0000000THIRD"
kc2_net_up
echo "== did:web server =="; kc2_didweb_up
echo "== IdentityHubs (trusted issuer) =="
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_boot_ih "$id" "$port" "$bpn" issuer; done
echo "== BDRS =="; kc2_boot_bdrs
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_ready "pilot08k2-$id-ih" "stored MembershipCredential for '$id'" || { echo "$id-ih NOT ready"; docker logs "pilot08k2-$id-ih" 2>&1 | tail -8; }; done
kc2_ready pilot08k2-bdrs " ready" || { echo "bdrs NOT ready"; docker logs pilot08k2-bdrs 2>&1 | tail -8; }
echo "== seed BDRS =="
declare -A SEED
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; SEED[$id]="$(kc2_seed_bdrs "$bpn" "$(kc2_did "$id" "$port")")"; echo "bdrs $bpn -> ${SEED[$id]}"; done
echo "== connectors =="
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_boot_conn "$id" "$bpn" "$port"; done
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_ready "pilot08k2-$id" " ready" || { echo "$id NOT ready"; docker logs "pilot08k2-$id" 2>&1 | tail -15; }; done

echo "== smoke (infrastructure rows only) =="
out="$PILOT/kc2/env/handshake-smoke.csv"
[ -f "$out" ] || echo "target,check,expected,got,ok,connector_digest,identityhub_jar_sha256,commit" > "$out"
row(){ local ok=no; [ "$2" = "$3" ] && ok=yes; echo "tractusx-0.13.0,$1,$2,$3,$ok,$CONN_DIGEST,$IHSHA,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
st(){ docker logs "$1" 2>&1 | grep -qE "$2" && echo ready || echo notready; }
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"
  row "${id}_ih_seeded_with_credential" ready "$(st "pilot08k2-$id-ih" "stored MembershipCredential for '$id'")"
  row "${id}_bdrs_seed" 204 "${SEED[$id]}"
  row "${id}_connector_booted" ready "$(st "pilot08k2-$id" " ready")"
done
row bdrs_booted ready "$(st pilot08k2-bdrs " ready")"
row issuer_did_resolves 200 "$(kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 8 http://issuer:8099/issuer/did.json)"
row dsp_catalog_no_token 401 "$(kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST http://provider:8082/api/v1/dsp/catalog/request -H 'content-type: application/json' -d '{"@context":{"dspace":"https://w3id.org/dspace/v0.8/"},"@type":"dspace:CatalogRequestMessage","dspace:filter":{}}')"
row dcp_catalog_trusted_issuer_consumer 200 "$(kc2_catalog_code consumer)"
row dcp_catalog_trusted_issuer_third 200 "$(kc2_catalog_code third)"
PDID="$(kc2_did provider 7084)"
body="$(kc2_drv -s --max-time 40 -X POST http://consumer:8081/management/v3/catalog/request -H 'x-api-key: consumer-mgmt' -H 'content-type: application/json' -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"CatalogRequest","counterPartyAddress":"http://provider:8082/api/v1/dsp","counterPartyId":"'"$PDID"'","protocol":"dataspace-protocol-http"}')"
row dcp_catalog_body_type dcat:Catalog "$(echo "$body" | "$JQ" -r '."@type"' 2>/dev/null)"
