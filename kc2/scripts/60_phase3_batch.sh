#!/usr/bin/env bash
# KC2 phase-3 batch runner (Review 15 U2), modelled on scripts/50_kc1_batch.sh. ORCHESTRATION ONLY: it holds
# no assertion logic. Each frozen invariant has a PRIVATE runner (gitignored):
#     private/kc2/scripts/inv<N>.sh <target> <config>      target: tractusx|vanilla   config: sanity|mutation|current
# which brings up what it needs (kc2/scripts/handshake_lib.sh), and ends its output with exactly one line
#     RESULT=PASS | RESULT=FAIL | RESULT=INVALID[:reason] | RESULT=NA[:reason]
# Admission (kc2/INVARIANTS.md, amendment A1): per invariant x target, sanity must be PASS and mutation must be
# FAIL; only then is the current-release cell run and counted. Otherwise the current cell is INVALID(admission)
# and is NOT run. A missing runner gives INVALID(no-runner); NA is reachability-not-applicable (e.g. INV-3).
#
# Rules: refuses a dirty tree; aborts if HEAD moves mid-batch; never starts Docker (run
# kc2/scripts/00_ensure_docker.ps1 by hand first); per-cell timeout; EVERY log and row goes under
# private/kc2/ via kc2_private_out; nothing is printed that is meant for a tracked file; do NOT commit or push
# while this runs. Tracked files never receive any phase-3 number (Review 15 U1).
# Usage: [INVS="1 2 ... 8"] [TARGETS="tractusx vanilla"] [CELL_TIMEOUT=1500] ./60_phase3_batch.sh
source "$(dirname "$0")/kc2lib.sh"   # lib.sh: set -euo pipefail, require_docker (check only), COMMIT, PILOT
INVS="${INVS:-1 2 3 4 5 6 7 8}"; TARGETS="${TARGETS:-tractusx vanilla}"; CELL_TIMEOUT="${CELL_TIMEOUT:-1500}"
RUNNERS="$PILOT/private/kc2/scripts"

case "$COMMIT" in *-dirty) echo "refusing: tree is dirty ($COMMIT) — commit first so every row cites a clean commit"; exit 1;; esac
for net in pilot08k2_dsp pilot08v; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    [ "$(docker network inspect "$net" --format '{{.Internal}}')" = true ] || { echo "refusing: network $net exists but is not internal"; exit 1; }
  fi
done
HEAD0="$(git -C "$PILOT" rev-parse HEAD)"
out="$(kc2_private_out phase3-cells.csv)"
[ -f "$out" ] || echo "invariant,target,config,result,detail,commit,started" > "$out"
logdir="$(dirname "$(kc2_private_out logs/.keep)")"; mkdir -p "$logdir"
clean(){ docker ps -aq --filter name=pilot08k2- --filter name=pilot08v- | xargs -r docker rm -f >/dev/null 2>&1 || true; }
echo "KC2 phase-3 batch @ $COMMIT (HEAD ${HEAD0:0:7}); INVS=[$INVS] TARGETS=[$TARGETS]; ${CELL_TIMEOUT}s/cell; output private only"

headcheck(){ [ "$(git -C "$PILOT" rev-parse HEAD)" = "$HEAD0" ] || { echo "refusing: HEAD moved mid-batch — aborting (rows must cite one commit)"; exit 1; }; }
cell(){ # inv target config -> echoes result token, appends a private row (runs in $(...): never exit here)
  local inv="$1" t="$2" c="$3" r log res detail rc
  r="$RUNNERS/inv$inv.sh"; log="$logdir/inv$inv-$t-$c.log"
  if [ ! -f "$r" ]; then res=INVALID; detail=no-runner
  else
    clean
    if timeout "$CELL_TIMEOUT" bash "$r" "$t" "$c" > "$log" 2>&1; then rc=0; else rc=$?; fi
    local line; line="$(grep -E '^RESULT=' "$log" | tail -1 || true)"
    if [ -z "$line" ]; then res=INVALID; detail="no-result(exit=$rc)"
    else res="${line#RESULT=}"; detail="${res#*:}"; res="${res%%:*}"; [ "$detail" = "$res" ] && detail=""
         case "$res" in PASS|FAIL|INVALID|NA) ;; *) detail="bad-token:$res"; res=INVALID;; esac; fi
  fi
  echo "INV-$inv,$t,$c,$res,$detail,$COMMIT,$(date -u +%FT%TZ)" >> "$out"
  echo "$res"
}

for t in $TARGETS; do
  for inv in $INVS; do
    headcheck; s="$(cell "$inv" "$t" sanity)"
    if [ "$s" = NA ]; then echo "INV-$inv,$t,current,NA,not-applicable(sanity),$COMMIT,$(date -u +%FT%TZ)" >> "$out"; continue; fi
    headcheck; m="$(cell "$inv" "$t" mutation)"
    if [ "$s" = PASS ] && [ "$m" = FAIL ]; then
      headcheck; cell "$inv" "$t" current >/dev/null
    else
      echo "INV-$inv,$t,current,INVALID,admission(sanity=$s;mutation=$m),$COMMIT,$(date -u +%FT%TZ)" >> "$out"
    fi
  done
done
clean
echo "phase-3 batch finished; rows in private/kc2/$(basename "$out"), logs in private/kc2/logs/ (not for tracked files)"
