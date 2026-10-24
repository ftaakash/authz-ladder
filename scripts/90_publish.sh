#!/usr/bin/env bash
# Publish new pilot commits to the public repo github.com/ftaakash/authz-ladder.
# Replays each local commit that touched pilots/08-dsp-authfuzz/ (paths made relative
# to the pilot dir) with its original author, date and message; only the
# "Co-Authored-By: Claude" trailer is removed. Normal push only, never force.
# Never publishes undisclosed findings: aborts if a patch touches a candidate/private
# path (C10), adds a result row for a build outside the admitted KC1 ladder, or names a
# candidate/undisclosed/new violation in an evidence file, a changed .md, or a commit message.
# --yes bypasses the content guard and is ALWAYS the user's call, decided per publish (a finding
# is disclosed) — it is never passed automatically.
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
# Content guard (C10/L8/M1): a KC2/new-violations phase produces undisclosed findings, which must
# never auto-publish. Unless --yes is given (finding disclosed, user's call), abort if a patch:
#   - adds a result row (…,FAIL,… / …,LEAK,…) for a build outside the admitted KC1 ladder, in an
#     EVIDENCE file (results/ or env/) or a candidate/private path; or
#   - adds a line naming a candidate/undisclosed/new violation in an evidence file, a changed *.md,
#     or a commit message (the patch header before the first "diff --git").
# Only this script's own hunk (scripts/90_publish.sh) is excluded, so the guard's wording here
# cannot self-match; all other scripts/docs are in scope for the keyword scan via .md / message.
if [ "$YES" = no ]; then
  bad="$(awk '
    FNR==1 { inmsg=1; inscope=0; md=0; self=0 }                      # each patch starts with its commit message
    /^diff --git / { inmsg=0; inscope=0; md=0; self=0 }
    inmsg {                                                          # commit message / headers (before first diff)
      if (tolower($0) ~ /candidate|undisclosed|new violation/) print "commit-message: " $0
      next
    }
    /^\+\+\+ b\// { p=substr($0,7)
                    self=(p ~ /(^|\/)scripts\/90_publish\.sh$/)
                    inscope=(p ~ /(^|\/)(results|env)\// || p ~ /candidate|CANDIDATE|\/private\//)
                    md=(p ~ /\.md$/) }
    /^\+[^+]/ {
      if (self) next
      l=substr($0,2)
      if (inscope && l ~ /,(FAIL|LEAK),/ && l !~ /^(0\.6\.2|0\.6\.3|0\.9\.0|0\.9\.1),/) print "FAIL/LEAK row outside ladder: " l
      if ((inscope || md) && tolower(l) ~ /candidate|undisclosed|new violation/)         print "candidate/undisclosed content: " l
    }' "$tmp"/*.patch)"
  if [ -n "$bad" ]; then echo "refusing to auto-publish (--yes is the user's call, once disclosed):"; echo "$bad" | head -8; exit 1; fi
fi
sed -i -E '/^Co-Authored-By: Claude.*$/Id' "$tmp"/*.patch

git -C "$MIR" am -q --committer-date-is-author-date "$tmp"/*.patch \
  || { git -C "$MIR" am --abort; echo "am failed; nothing pushed"; exit 1; }
git -C "$MIR" push -q origin main
echo "$head" > "$marker"
echo "published $(ls "$tmp"/*.patch | wc -l) commit(s) up to ${head:0:7}"
