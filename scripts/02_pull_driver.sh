#!/usr/bin/env bash
# Pull the harness driver image by digest and retag it locally. Idempotent.
# Logged in ENV.md (name, source, digest, size, date). Needs egress (build/pull
# step only; the runtime testbed network stays internal).
source "$(dirname "$0")/lib.sh"
SRC="curlimages/curl@sha256:c1fe1679c34d9784c1b0d1e5f62ac0a79fca01fb6377cdd33e90473c6f9f9a69"
docker pull -q "$SRC" >/dev/null
docker tag "$SRC" pilot08/curl:8.11.1
echo "driver image ready: pilot08/curl:8.11.1 <- $SRC"
