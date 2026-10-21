#!/usr/bin/env bash
# Generate local-only EC P-256 test keys for each testbed participant. Idempotent.
source "$(dirname "$0")/lib.sh"
S="$PILOT/testbed/.secrets"; mkdir -p "$S"
for who in provider consumer; do
  [ -f "$S/$who.key.pem" ] && continue
  openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$S/$who.key.pem" 2>/dev/null
  openssl pkey -in "$S/$who.key.pem" -pubout -out "$S/$who.pub.pem" 2>/dev/null
  echo "generated $who"
done
