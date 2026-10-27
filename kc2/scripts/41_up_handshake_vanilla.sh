#!/usr/bin/env bash
# KC2 step 2 — DCP handshake bring-up for the SECOND target: vanilla Eclipse EDC 0.18.1 (local testbed only).
# Same shared 0.17.0 identity stack (D12): issuer did:web server; provider, consumer, third IdentityHubs
# with MembershipCredentials from the TRUSTED issuer. The Tractus-X scope-alias adapter is OFF
# (KC2_TXSCOPE=false): vanilla requests the DCP alias natively. Vanilla has no BDRS client (participant
# ids are DIDs), so no BDRS here. DSP profile: dataspace-protocol-http:2025-1 at /api/v1/dsp/2025-1.
# Records INFRASTRUCTURE rows only (Review 13 S3) in kc2/env/handshake-smoke.csv (target vanilla-0.18.1).
source "$(dirname "$0")/handshake_lib.sh"

IHSHA="$(sha256sum "$IHJAR" | cut -d' ' -f1)"
grep -qE "^identityhub,[0-9.]+,$IHSHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/identity-jars.csv" 2>/dev/null \
  || { echo "IdentityHub jar sha $IHSHA not recorded at a clean commit — run 10_build_identity.sh on a clean tree"; exit 1; }
VSHA="$(sha256sum "$VJAR" | cut -d' ' -f1)"
grep -qE "^0\.18\.1,$VSHA,[0-9]+,[0-9a-f]{7}," "$PILOT/kc2/env/vanilla018-jars.csv" 2>/dev/null \
  || { echo "vanilla jar sha $VSHA not recorded at a clean commit — run 11_build_vanilla.sh on a clean tree"; exit 1; }

PARTS="provider:7084:BPNL000000PROVIDER consumer:7086:BPNL000000CONSUMER third:7088:BPNL0000000THIRD"
docker rm -f $(docker ps -aq --filter name=pilot08k2-) >/dev/null 2>&1   # fresh caches: IdentityHubs before connectors
kc2_net_up
echo "== did:web server =="; kc2_didweb_up
echo "== IdentityHubs (trusted issuer; Tractus-X scope adapter OFF) =="
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; KC2_TXSCOPE=false kc2_boot_ih "$id" "$port" "$bpn" issuer; done
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_ready "pilot08k2-$id-ih" "stored MembershipCredential for '$id'" || { echo "$id-ih NOT ready"; docker logs "pilot08k2-$id-ih" 2>&1 | tail -8; }; done
echo "== vanilla connectors =="
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_boot_vconn "$id" "$port"; done
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"; kc2_ready "pilot08k2-v$id" " ready" || { echo "v$id NOT ready"; docker logs "pilot08k2-v$id" 2>&1 | grep -E "SEVERE|ERROR" | head -10; }; done

echo "== smoke (infrastructure rows only) =="
out="$PILOT/kc2/env/handshake-smoke.csv"
[ -f "$out" ] || echo "target,check,expected,got,ok,connector_digest,identityhub_jar_sha256,commit" > "$out"
# for the vanilla target the connector_digest column holds the fat-jar sha256 (no image)
row(){ local ok=no; [ "$2" = "$3" ] && ok=yes; echo "vanilla-0.18.1,$1,$2,$3,$ok,$VSHA,$IHSHA,$COMMIT" >> "$out"; echo "$1 expected=$2 got=$3 ok=$ok"; }
st(){ docker logs "$1" 2>&1 | grep -qE "$2" && echo "$3" || echo "not-$3"; }
for p in $PARTS; do IFS=: read -r id port bpn <<<"$p"
  row "${id}_ih_seeded_with_credential" ready "$(st "pilot08k2-$id-ih" "stored MembershipCredential for '$id'" ready)"
  row "${id}_connector_booted" ready "$(st "pilot08k2-v$id" " ready" ready)"
done
row scope_adapter OFF "$(docker logs pilot08k2-provider-ih 2>&1 | grep -oE 'adapter O(N|FF)' | tail -1 | sed 's/adapter //')"
row issuer_did_resolves 200 "$(kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 8 http://issuer:8099/issuer/did.json)"
row dsp_catalog_no_token 401 "$(kc2_drv -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST http://vprovider:8082/api/v1/dsp/2025-1/catalog/request -H 'content-type: application/json' -d '{"@context":["https://w3id.org/dspace/2025/1/context.jsonld"],"@type":"CatalogRequestMessage","filter":[]}')"
row dcp_catalog_trusted_issuer_consumer 200 "$(kc2_vcatalog_code consumer)"
row dcp_catalog_trusted_issuer_third 200 "$(kc2_vcatalog_code third)"
PDID="$(kc2_did provider 7084)"
body="$(kc2_drv -s --max-time 40 -X POST http://vconsumer:8081/management/v3/catalog/request -H 'x-api-key: vconsumer-mgmt' -H 'content-type: application/json' -d '{"@context":{"@vocab":"https://w3id.org/edc/v0.0.1/ns/"},"@type":"CatalogRequest","counterPartyAddress":"http://vprovider:8082/api/v1/dsp/2025-1","counterPartyId":"'"$PDID"'","protocol":"dataspace-protocol-http:2025-1"}')"
row dcp_catalog_body_type Catalog "$(echo "$body" | "$JQ" -r '."@type"' 2>/dev/null | sed 's/^dcat://')"
