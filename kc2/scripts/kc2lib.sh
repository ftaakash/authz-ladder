#!/usr/bin/env bash
# KC2 shared helpers. Any script that runs a test/assertion against a CURRENT target, or writes
# verdicts/observations/finding notes, MUST route output through kc2_private_out (SCOPE + Review 11 Q3).
# A smoke catalogue request against a current release can already expose a finding, so results go
# ONLY under pilots/08-dsp-authfuzz/private/kc2/ (gitignored by pilots/**/private/), never results/ or env/.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
KC2_PRIVATE="$PILOT/private/kc2"

# kc2_private_out <relative-name> -> absolute path under private/kc2/, creating the dir.
# Refuses any path that points at results/ or escapes private/kc2/.
kc2_private_out() {
  local name="$1"
  case "$name" in
    */results/*|results/*|*..*|/*) echo "REFUSED: KC2 output must be a plain name under private/kc2/ (got '$name')" >&2; exit 2;;
  esac
  mkdir -p "$KC2_PRIVATE"
  local abs="$KC2_PRIVATE/$name"
  # hard stop: the resolved path must be inside private/kc2/ and git must ignore it
  git -C "$PILOT" check-ignore -q "$abs" || { echo "REFUSED: $abs is not gitignored — aborting to protect undisclosed findings" >&2; exit 2; }
  echo "$abs"
}
