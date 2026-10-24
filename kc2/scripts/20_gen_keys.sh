#!/usr/bin/env bash
# KC2: generate local-only EC P-256 test keys under testbed/.secrets/kc2/ (gitignored, NEVER committed).
#
# CONSUMERS (Review 12 R9): the phase-2 identity bring-up does NOT consume these. Each IdentityHub
# generates its OWN Ed25519 keypair internally (via the seed extension's keyGeneratorParams) and holds
# the private key only in its ephemeral in-memory vault, so did:web resolution needs no key from here.
# These P-256 keys are RESERVED for the deferred connector DCP handshake phase (e.g. a connector's
# edc.iam.sts.oauth client-secret / transfer-proxy token-signer aliases), whose exact aliases are not
# yet fixed. Until that phase defines them, no bring-up runs this script; it is kept as the generator.
# Idempotent. Also emits a public JWK next to each key.
source "$(dirname "$0")/../../scripts/lib.sh"
S="$PILOT/testbed/.secrets/kc2"; mkdir -p "$S"
for who in provider consumer issuer; do
  [ -f "$S/$who.key.pem" ] && { echo "exists $who"; continue; }
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$S/$who.key.pem" 2>/dev/null
  openssl pkey -in "$S/$who.key.pem" -pubout -out "$S/$who.pub.pem" 2>/dev/null
  echo "generated $who"
done
ls -1 "$S"
