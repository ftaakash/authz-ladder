#!/usr/bin/env bash
# KC2: generate local-only EC P-256 test keys for each identity (provider, consumer, issuer).
# Keys live under testbed/.secrets/kc2/ (gitignored by pilots/**/testbed/.secrets/). NEVER committed.
# Idempotent. Also emits a public JWK (for the did:web document) next to each key.
source "$(dirname "$0")/../../scripts/lib.sh"
S="$PILOT/testbed/.secrets/kc2"; mkdir -p "$S"
for who in provider consumer issuer; do
  [ -f "$S/$who.key.pem" ] && { echo "exists $who"; continue; }
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$S/$who.key.pem" 2>/dev/null
  openssl pkey -in "$S/$who.key.pem" -pubout -out "$S/$who.pub.pem" 2>/dev/null
  echo "generated $who"
done
ls -1 "$S"
