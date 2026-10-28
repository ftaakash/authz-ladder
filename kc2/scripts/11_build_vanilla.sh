#!/usr/bin/env bash
# Build KC2 jars inside the pinned gradle container (host JVM has no loopback). Build has egress (Maven
# Central); the runtime testbed stays internal. Append-only jar records, keyed by id+sha+commit.
#   ROLE unset  : vanilla EDC 0.18.1 DCP connector   -> kc2/env/vanilla018-jars.csv
#   ROLE=tck    : vanilla 0.18.1 DSP-TCK runtime      -> kc2/env/tck-jars.csv (id vanilla-0.18.1)
#   ROLE=tck-tx : Tractus-X 0.13.0 DSP-TCK add-on jar  -> kc2/env/tck-jars.csv (id tractusx-0.13.0-addon)
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
ROLE="${ROLE:-}"; V="${EDC_V:-0.18.1}"
gbuild(){ MSYS_NO_PATHCONV=1 docker run --rm -v "$1":/work -w /work -v pilot08-gradle-cache:/home/gradle/.gradle \
  "$GRADLE_IMG" gradle --console=plain --no-daemon shadowJar "${@:2}"; }
rec(){ # csv id jar
  local csv="$1" id="$2" jar="$3" sha; sha="$(sha256sum "$jar" | cut -d' ' -f1)"
  [ -f "$csv" ] || echo "id,sha256,bytes,commit,date" > "$csv"
  grep -qE "^$id,$sha,[0-9]+,$COMMIT," "$csv" || echo "$id,$sha,$(wc -c < "$jar"),$COMMIT,$(date +%F)" >> "$csv"
  echo "built $id -> sha256=$sha"; }
case "$ROLE" in
  "")
    SRC="$PILOT/kc2/vanilla"; gbuild "$SRC" -Pedc="$V"
    jar="$SRC/build/libs/pilot08kc2-vanilla-all.jar"; [ -f "$jar" ] || { echo "build failed"; exit 1; }
    vjar="$SRC/build/libs/pilot08kc2-vanilla-$V.jar"; cp "$jar" "$vjar"
    sha="$(sha256sum "$vjar" | cut -d' ' -f1)"; csv="$PILOT/kc2/env/vanilla018-jars.csv"
    [ -f "$csv" ] || echo "edc_version,sha256,bytes,commit,date" > "$csv"
    grep -qE "^$V,$sha,[0-9]+,$COMMIT," "$csv" || echo "$V,$sha,$(wc -c < "$vjar"),$COMMIT,$(date +%F)" >> "$csv"
    echo "built vanilla $V -> sha256=$sha" ;;
  tck)
    SRC="$PILOT/kc2/vanilla"; gbuild "$SRC" -Pedc="$V" -Prole=tck
    jar="$SRC/build/libs/pilot08kc2-vanilla-tck-all.jar"; [ -f "$jar" ] || { echo "build failed"; exit 1; }
    tjar="$SRC/build/libs/pilot08kc2-vanilla-tck-$V.jar"; cp "$jar" "$tjar"
    rec "$PILOT/kc2/env/tck-jars.csv" "vanilla-$V" "$tjar" ;;
  tck-tx)
    SRC="$PILOT/kc2/tck-tx"; gbuild "$SRC"
    jar="$SRC/build/libs/pilot08kc2-tck-tx-addon.jar"; [ -f "$jar" ] || { echo "build failed"; exit 1; }
    rec "$PILOT/kc2/env/tck-jars.csv" "tractusx-0.13.0-addon" "$jar" ;;
  *) echo "unknown ROLE=$ROLE"; exit 2;;
esac
