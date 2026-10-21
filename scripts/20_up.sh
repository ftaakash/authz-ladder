#!/usr/bin/env bash
# Bring up one rung: ./20_up.sh <tx_tag>. Waits for the provider health check.
source "$(dirname "$0")/lib.sh"
TX_TAG="${1:?usage: 20_up.sh <tx_tag>}"; export TX_TAG
bash "$PILOT/scripts/10_gen_keys.sh"
S="$PILOT/testbed/.secrets"
# Memory-vault seed format is "alias:value;alias:value" (Tractus-X memory runtime).
export PROVIDER_VAULT_SECRETS="sts-client-secret:pilot08-sts-secret;token-signer:$(cat "$S/provider.key.pem");token-verifier:$(cat "$S/provider.pub.pem")"
docker compose -f "$PILOT/testbed/compose.yaml" up -d provider
# The network is internal (no host-published ports), so poll health through the
# driver container by service name, not via 127.0.0.1 on the host.
for _ in $(seq 1 60); do
  drv -sf --max-time 4 http://provider:8080/api/check/health >/dev/null 2>&1 && { echo "provider healthy on $TX_TAG"; exit 0; }
  sleep 2
done
echo "provider NOT healthy on $TX_TAG"; docker compose -f "$PILOT/testbed/compose.yaml" logs --tail 60 provider; exit 1
