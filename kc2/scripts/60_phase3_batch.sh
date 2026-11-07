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
# Driver versioning (Review 18 W3): the rows are produced by the gitignored private runners, which the clean
# commit stamp does NOT cover. So at start the batch snapshots every private driver to
# private/kc2/batches/<commit>-<utc>/ (with a sha256 MANIFEST), stamps each row with driver_sha256 (sha256 of
# inv<N>.sh + p3lib.sh as run) and the snapshot id, and REFUSES to continue if any driver changes after the
# snapshot. The final report cites the snapshot id alongside the clean commit.
# Rules: refuses a dirty tree; aborts if HEAD moves mid-batch; never starts Docker (run
# kc2/scripts/00_ensure_docker.ps1 by hand first); per-cell timeout; EVERY log and row goes under
# private/kc2/ via kc2_private_out; nothing is printed that is meant for a tracked file; do NOT commit or push
# while this runs. Tracked files never receive any phase-3 number (Review 15 U1).
# RUN_KIND=dryrun marks a NON-COUNTING rehearsal: it writes to a separate output file (phase3-cells-dryrun.csv),
# prefixes the driver-snapshot dir with "dryrun-", and stamps every row run_kind=dryrun, so a rehearsal can never
# be cited, merged into, or mistaken for the counting batch (default RUN_KIND=real). A dry run shakes out
# end-to-end orchestration only; its rows are discarded/archived separately before the counting run.
# Usage: [INVS="1 2 ... 8"] [TARGETS="tractusx vanilla"] [CELL_TIMEOUT=1500] [RUN_KIND=real|dryrun] ./60_phase3_batch.sh
source "$(dirname "$0")/kc2lib.sh"   # lib.sh: set -euo pipefail, require_docker (check only), COMMIT, PILOT
INVS="${INVS:-1 2 3 4 5 6 7 8}"; TARGETS="${TARGETS:-tractusx vanilla}"; CELL_TIMEOUT="${CELL_TIMEOUT:-1500}"
RUN_KIND="${RUN_KIND:-real}"; case "$RUN_KIND" in real|dryrun) ;; *) echo "refusing: RUN_KIND must be real|dryrun (got '$RUN_KIND')"; exit 1;; esac
RUNNERS="$PILOT/private/kc2/scripts"

case "$COMMIT" in *-dirty) echo "refusing: tree is dirty ($COMMIT) — commit first so every row cites a clean commit"; exit 1;; esac
for net in pilot08k2_dsp pilot08v; do
  if docker network inspect "$net" >/dev/null 2>&1; then
    [ "$(docker network inspect "$net" --format '{{.Internal}}')" = true ] || { echo "refusing: network $net exists but is not internal"; exit 1; }
  fi
done
HEAD0="$(git -C "$PILOT" rev-parse HEAD)"
# W3: snapshot the gitignored private drivers (commit stamp does not cover them) and pin their shas.
SNAP_ID="${COMMIT}-$(date -u +%Y%m%dT%H%M%SZ)"; [ "$RUN_KIND" = dryrun ] && SNAP_ID="dryrun-$SNAP_ID"
snapdir="$(dirname "$(kc2_private_out "batches/$SNAP_ID/.keep")")"; mkdir -p "$snapdir"
cp "$RUNNERS"/*.sh "$snapdir"/ 2>/dev/null || true
( cd "$RUNNERS" && for f in *.sh; do sha256sum "$f"; done ) > "$snapdir/MANIFEST.sha256" 2>/dev/null || true
echo "driver snapshot: private/kc2/batches/$SNAP_ID/ ($(ls "$RUNNERS"/*.sh 2>/dev/null | wc -l) private drivers; sha manifest inside)"
out="$(kc2_private_out "phase3-cells$([ "$RUN_KIND" = dryrun ] && echo -dryrun).csv")"
[ -f "$out" ] || echo "invariant,target,config,result,detail,commit,driver_sha256,snapshot,started,admission,run_kind" > "$out"
# A3 (weaker, mutation-NA) admission allow-list (Review 20 Y2). It is EMPTY by default: with INV-4 now admitted
# at the A1 tier (its two-layer mutation violates by construction, amendment A3 rev. 2026-11-06), no invariant uses the
# NA-admission path, so every sanity-PASS + mutation-NA is INVALID:admission. The mechanism is retained (set
# A3_ALLOW="<inv>:<target>" + A3_REASON) only if a future invariant genuinely has no single-check mutation.
A3_ALLOW="${A3_ALLOW:-}"; A3_REASON="${A3_REASON:-__never__}"
logdir="$(dirname "$(kc2_private_out logs/.keep)")"; mkdir -p "$logdir"
clean(){ docker ps -aq --filter name=pilot08k2- --filter name=pilot08v- | xargs -r docker rm -f >/dev/null 2>&1 || true; }
[ "$RUN_KIND" = dryrun ] && echo "*** DRY RUN (run_kind=dryrun): NON-COUNTING rehearsal — rows are never cited/merged into the counting batch ***"
echo "KC2 phase-3 batch @ $COMMIT (HEAD ${HEAD0:0:7}); run_kind=$RUN_KIND; INVS=[$INVS] TARGETS=[$TARGETS]; ${CELL_TIMEOUT}s/cell; output private only"

headcheck(){ [ "$(git -C "$PILOT" rev-parse HEAD)" = "$HEAD0" ] || { echo "refusing: HEAD moved mid-batch — aborting (rows must cite one commit)"; exit 1; }; }
# W3 driver versioning: sha of the gitignored code that produces a row, and a guard that aborts if it drifts.
driversha(){ local inv="$1"; [ -f "$RUNNERS/inv$inv.sh" ] || { echo ""; return; }; cat "$RUNNERS/inv$inv.sh" "$RUNNERS/p3lib.sh" | sha256sum | cut -d' ' -f1; }
drivercheck(){ local inv="$1" f; for f in "inv$inv.sh" p3lib.sh; do [ -f "$RUNNERS/$f" ] || continue
    cmp -s "$RUNNERS/$f" "$snapdir/$f" || { echo "refusing: private driver $f changed after snapshot $SNAP_ID — restart the batch so every row cites the code that produced it"; exit 1; }
  done; }
cell(){ # inv target config [admission] -> echoes result token, appends a private row (runs in $(...): never exit here)
  local inv="$1" t="$2" c="$3" adm="${4:--}" r log res detail rc
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
  echo "INV-$inv,$t,$c,$res,$detail,$COMMIT,$dsha,$SNAP_ID,$(date -u +%FT%TZ),$adm,$RUN_KIND" >> "$out"
  echo "$res"
}

for t in $TARGETS; do
  for inv in $INVS; do
    dsha="$(driversha "$inv")"
    headcheck; drivercheck "$inv"; s="$(cell "$inv" "$t" sanity)"
    if [ "$s" = NA ]; then echo "INV-$inv,$t,current,NA,not-applicable(sanity),$COMMIT,$dsha,$SNAP_ID,$(date -u +%FT%TZ),-,$RUN_KIND" >> "$out"; continue; fi
    headcheck; drivercheck "$inv"; m="$(cell "$inv" "$t" mutation)"
    mdetail="$(grep -E "^INV-$inv,$t,mutation," "$out" | tail -1 | cut -d, -f5)"
    if [ "$s" = PASS ] && [ "$m" = FAIL ]; then
      # A1 admission: sanity holds + mutation reveals the violation -> current counts.
      headcheck; drivercheck "$inv"; cell "$inv" "$t" current A1 >/dev/null
    elif [ "$s" = PASS ] && [ "$m" = NA ] && printf '%s' " $A3_ALLOW " | grep -q " $inv:$t " && printf '%s' "$mdetail" | grep -q "$A3_REASON"; then
      # A3 admission (amendment A3), allow-listed only: layered enforcement means no single-check mutation is
      # possible, so this (invariant:target) is admitted on positive-control (sanity) + assertion (current).
      headcheck; drivercheck "$inv"; cell "$inv" "$t" current A3 >/dev/null
    else
      echo "INV-$inv,$t,current,INVALID,admission(sanity=$s;mutation=$m),$COMMIT,$dsha,$SNAP_ID,$(date -u +%FT%TZ),-,$RUN_KIND" >> "$out"
    fi
  done
done
clean
echo "phase-3 batch finished; snapshot private/kc2/batches/$SNAP_ID/; rows in private/kc2/$(basename "$out") (driver_sha256 + snapshot per row), logs in private/kc2/logs/ (not for tracked files)"
