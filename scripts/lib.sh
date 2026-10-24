#!/usr/bin/env bash
# Shared helpers for pilot 08 scripts. Local testbed only.
set -euo pipefail
PILOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JQ="${JQ:-/c/Users/Administrator/tools/jq/jq.exe}"
PINS="$PILOT/env/pins.tsv"
COMMIT="$(git -C "$PILOT" rev-parse --short HEAD)"
# Dirty-tree marker so results never claim a clean commit they did not run on.
# Evidence outputs (env/*.csv, kc2/env/*.csv, results/) are excluded: writing them is not a code change.
# Tracked changes AND untracked files (e.g. a new, uncommitted script) both mark dirty.
_dirty=no
git -C "$PILOT" diff --quiet HEAD -- . ':(exclude)env/*.csv' ':(exclude)results' ':(exclude)kc2/env/*.csv' || _dirty=yes
[ -n "$(git -C "$PILOT" ls-files --others --exclude-standard -- . ':(exclude)env/*.csv' ':(exclude)results' ':(exclude)kc2/env/*.csv' 2>/dev/null)" ] && _dirty=yes
[ "$_dirty" = yes ] && COMMIT="${COMMIT}-dirty"
local_tag() { echo "pilot08/edc-runtime-memory:$1"; }
pins() { grep -v '^#' "$PINS"; }

# The testbed network is internal (no egress, SCOPE local-only), so Docker does
# not publish container ports to the host. The harness therefore runs from an
# ephemeral driver container joined to the network, reaching connectors by name.
NET="${NET:-pilot08_dsp}"
DRIVER_IMG="${DRIVER_IMG:-pilot08/curl:8.11.1}"
drv() { docker run --rm --network "$NET" "$DRIVER_IMG" "$@"; }
# A test script must NEVER start Docker: launching Docker Desktop.exe & from inside a script
# leaves a native MSYS child the script cannot outlive, which hangs the whole run (N1). Only check.
require_docker() {
  docker info >/dev/null 2>&1 || { echo "docker engine not available, start Docker Desktop and re-run" >&2; exit 3; }
}
require_docker
