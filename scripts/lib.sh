#!/usr/bin/env bash
# Shared helpers for pilot 08 scripts. Local testbed only.
set -euo pipefail
PILOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JQ="${JQ:-/c/Users/Administrator/tools/jq/jq.exe}"
PINS="$PILOT/env/pins.tsv"
COMMIT="$(git -C "$PILOT" rev-parse --short HEAD)"
# Dirty-tree marker so results never claim a clean commit they did not run on.
# Evidence outputs (env/*.csv, results/) are excluded: writing them is not a code change.
# Tracked changes AND untracked files (e.g. a new, uncommitted script) both mark dirty.
_dirty=no
git -C "$PILOT" diff --quiet HEAD -- . ':(exclude)env/*.csv' ':(exclude)results' || _dirty=yes
[ -n "$(git -C "$PILOT" ls-files --others --exclude-standard -- . ':(exclude)env/*.csv' ':(exclude)results' 2>/dev/null)" ] && _dirty=yes
[ "$_dirty" = yes ] && COMMIT="${COMMIT}-dirty"
local_tag() { echo "pilot08/edc-runtime-memory:$1"; }
pins() { grep -v '^#' "$PINS"; }

# The testbed network is internal (no egress, SCOPE local-only), so Docker does
# not publish container ports to the host. The harness therefore runs from an
# ephemeral driver container joined to the network, reaching connectors by name.
NET="${NET:-pilot08_dsp}"
DRIVER_IMG="${DRIVER_IMG:-pilot08/curl:8.11.1}"
drv() { docker run --rm --network "$NET" "$DRIVER_IMG" "$@"; }
# Start the local Docker engine if it is down (Docker Desktop on this host), wait up to 3 min.
DOCKER_DESKTOP="${DOCKER_DESKTOP:-/c/Users/Administrator/AppData/Local/Programs/DockerDesktop/Docker Desktop.exe}"
require_docker() {
  docker info >/dev/null 2>&1 && return 0
  [ -x "$DOCKER_DESKTOP" ] && "$DOCKER_DESKTOP" >/dev/null 2>&1 &
  for _ in $(seq 1 60); do docker info >/dev/null 2>&1 && return 0; sleep 3; done
  echo "docker engine not available" >&2; return 1
}
require_docker
