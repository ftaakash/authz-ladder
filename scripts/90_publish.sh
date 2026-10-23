#!/usr/bin/env bash
# Publish new pilot commits to the public repo github.com/ftaakash/authz-ladder.
# Replays each local commit that touched pilots/08-dsp-authfuzz/ (paths made relative
# to the pilot dir) with its original author, date and message; only the
# "Co-Authored-By: Claude" trailer is removed. Normal push only, never force.
# Never publishes undisclosed findings: aborts if a patch touches a candidate/private
# path (C10), adds a result row for a build outside the admitted KC1 ladder, or names a
# candidate/undisclosed/new violation. Pass --yes only once such a finding is disclosed.
# Usage: ./90_publish.sh [--yes]    (run after each completed phase, on a clean tree)
set -euo pipefail
YES=no; [ "${1:-}" = "--yes" ] && YES=yes
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
# Content guard (C10/L8): a KC2/new-violations phase produces undisclosed findings, which must
# never auto-publish. The scan is scoped to EVIDENCE/notes files (results/, env/, or a candidate/
# private path) via each hunk's "+++ b/<path>" header — scripts and docs are skipped so this
# guard's own wording here cannot self-match. Within those files, unless --yes is given (finding
# disclosed), an added result row (…,FAIL,… / …,LEAK,…) for a build outside the admitted KC1 ladder,
# or an added line naming a candidate/undisclosed/new violation, aborts the publish.
if [ "$YES" = no ]; then
  bad="$(awk '
    /^diff --git / { inscope=0 }
    /^\+\+\+ b\// { p=substr($0,7); inscope=(p ~ /(^|\/)(results|env)\// || p ~ /candidate|CANDIDATE|\/private\//) }
    inscope && /^\+[^+]/ {
      l=substr($0,2)
      if (l ~ /,(FAIL|LEAK),/ && l !~ /^(0\.6\.2|0\.6\.3|0\.9\.0|0\.9\.1),/) print "FAIL/LEAK row outside ladder: " l
      if (tolower(l) ~ /candidate|undisclosed|new violation/)            print "candidate/undisclosed content: " l
    }' "$tmp"/*.patch)"
  if [ -n "$bad" ]; then echo "refusing to auto-publish (pass --yes once disclosed):"; echo "$bad" | head -5; exit 1; fi
fi
sed -i -E '/^Co-Authored-By: Claude.*$/Id' "$tmp"/*.patch

git -C "$MIR" am -q --committer-date-is-author-date "$tmp"/*.patch \
  || { git -C "$MIR" am --abort; echo "am failed; nothing pushed"; exit 1; }
git -C "$MIR" push -q origin main
echo "$head" > "$marker"
echo "published $(ls "$tmp"/*.patch | wc -l) commit(s) up to ${head:0:7}"
