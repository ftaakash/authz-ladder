#!/usr/bin/env bash
# KC1 batch runner: the two admitted regression tests across the vanilla ladder, from ONE clean
# HEAD. -4536 (DSP-driven) x4 then -9202 (catalogue) x4 over 0.6.2/0.6.3/0.9.0/0.9.1.
# Design rules (Review 9 N3): never starts Docker (lib.sh only checks); never rm's evidence files
# (each test replaces its own version's row); aborts if HEAD moves mid-batch; per-rung log under
# build/logs (gitignored; the tests already redact the canary); 900s timeout per rung.
# Do NOT commit or push while this runs. Usage: ./50_kc1_batch.sh
source "$(dirname "$0")/lib.sh"   # set -euo pipefail; require_docker (checks only, exit 3); COMMIT; PILOT
NET="pilot08v"
clean_containers() { docker ps -aq --filter "name=$NET" | xargs -r docker rm -f >/dev/null 2>&1 || true; }

# --- preflight ---
case "$COMMIT" in *-dirty) echo "refusing: tree is dirty ($COMMIT) — commit first so result rows cite a clean commit"; exit 1;; esac
if docker network inspect "$NET" >/dev/null 2>&1; then
  [ "$(docker network inspect "$NET" --format '{{.Internal}}')" = true ] || { echo "refusing: network $NET exists but is not internal"; exit 1; }
else
  docker network create --internal "$NET" >/dev/null
fi
HEAD0="$(git -C "$PILOT" rev-parse HEAD)"
LOGD="$PILOT/build/logs"; mkdir -p "$LOGD"
echo "KC1 batch @ commit $COMMIT (HEAD ${HEAD0:0:7}), network $NET internal, 900s/rung"

run_rung() {           # <cve-label> <test-script> <version>
  local cve scr V rc
  cve="$1"; scr="$2"; V="$3"
  [ "$(git -C "$PILOT" rev-parse HEAD)" = "$HEAD0" ] || { echo "refusing: HEAD moved mid-batch — aborting (evidence must cite one commit)"; exit 1; }
  echo "===== $cve $V ====="
  if timeout 900 bash "$PILOT/scripts/$scr" "$V" > "$LOGD/$cve-$V.log" 2>&1; then rc=0; else rc=$?; fi
  echo "$cve $V exit=$rc"
  [ "$rc" = 0 ] || { echo "--- tail $cve-$V.log ---"; tail -5 "$LOGD/$cve-$V.log"; }
  tail -1 "$LOGD/$cve-$V.log"
  clean_containers
}

clean_containers
for V in 0.6.2 0.6.3 0.9.0 0.9.1; do run_rung cve-2024-4536 42_test_4536_dsp.sh "$V"; done
for V in 0.6.2 0.6.3 0.9.0 0.9.1; do run_rung cve-2024-9202 40_test_9202.sh "$V"; done

echo "########## results/cve-2024-4536.csv ##########"; cat "$PILOT/results/cve-2024-4536.csv" 2>/dev/null
echo "########## results/cve-2024-9202.csv ##########"; cat "$PILOT/results/cve-2024-9202.csv" 2>/dev/null
