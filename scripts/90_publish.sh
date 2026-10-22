#!/usr/bin/env bash
# Publish new pilot commits to the public repo github.com/ftaakash/authz-ladder.
# Replays each local commit that touched pilots/08-dsp-authfuzz/ (paths made relative
# to the pilot dir) with its original author, date and message; only the
# "Co-Authored-By: Claude" trailer is removed. Normal push only, never force.
# Never publishes undisclosed findings: aborts if a patch touches a candidate/private path.
# Usage: ./90_publish.sh            (run after each completed phase, on a clean tree)
set -euo pipefail
PILOT="$(cd "$(dirname "$0")/.." && pwd)"   # no lib.sh: publishing needs no Docker
ROOT="$(git -C "$PILOT" rev-parse --show-toplevel)"
REL="pilots/08-dsp-authfuzz"
MIR="$PILOT/build/publish/authz-ladder"        # build/ is gitignored
URL="https://github.com/ftaakash/authz-ladder.git"

[ -d "$MIR/.git" ] || git clone -q "$URL" "$MIR"
git -C "$MIR" pull -q --ff-only origin main
marker="$MIR/.git/pilot-last"                   # last local commit already published
[ -f "$marker" ] || { echo "missing $marker (bootstrap: echo <sha> > it)"; exit 1; }
last="$(cat "$marker")"; head="$(git -C "$ROOT" rev-parse HEAD)"
[ "$last" = "$head" ] && { echo "nothing to publish"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git -C "$ROOT" format-patch -q --relative="$REL" -o "$tmp" "$last..$head" -- "$REL"
if ! ls "$tmp"/*.patch >/dev/null 2>&1; then echo "$head" > "$marker"; echo "no pilot changes"; exit 0; fi

# Scope guard (SCOPE.md: candidate findings never enter public history).
if grep -l -i -E '^diff --git a/.*(candidate-findings|CANDIDATE-|/private/)' "$tmp"/*.patch; then
  echo "refusing: a patch touches a candidate/private path"; exit 1
fi
sed -i -E '/^Co-Authored-By: Claude.*$/Id' "$tmp"/*.patch

git -C "$MIR" am -q --committer-date-is-author-date "$tmp"/*.patch \
  || { git -C "$MIR" am --abort; echo "am failed; nothing pushed"; exit 1; }
git -C "$MIR" push -q origin main
echo "$head" > "$marker"
echo "published $(ls "$tmp"/*.patch | wc -l) commit(s) up to ${head:0:7}"
