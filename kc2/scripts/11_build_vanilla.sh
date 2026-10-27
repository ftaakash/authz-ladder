#!/usr/bin/env bash
# Build the KC2 vanilla Eclipse EDC 0.18.1 DCP connector fat jar from the pinned Maven Central BOMs,
# inside the pinned gradle container (host JVM has no loopback). Build has egress; runtime stays internal.
# Records kc2/env/vanilla018-jars.csv (append-only, keyed by version+sha+commit).
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
SRC="$PILOT/kc2/vanilla"; V="${EDC_V:-0.18.1}"
MSYS_NO_PATHCONV=1 docker run --rm -v "$SRC":/work -w /work -v pilot08-gradle-cache:/home/gradle/.gradle \
  "$GRADLE_IMG" gradle --console=plain --no-daemon shadowJar -Pedc="$V"
jar="$SRC/build/libs/pilot08kc2-vanilla-all.jar"; [ -f "$jar" ] || { echo "build failed: no jar"; exit 1; }
vjar="$SRC/build/libs/pilot08kc2-vanilla-$V.jar"; cp "$jar" "$vjar"
sha="$(sha256sum "$vjar" | cut -d' ' -f1)"
csv="$PILOT/kc2/env/vanilla018-jars.csv"; [ -f "$csv" ] || echo "edc_version,sha256,bytes,commit,date" > "$csv"
grep -qE "^$V,$sha,[0-9]+,$COMMIT," "$csv" || echo "$V,$sha,$(wc -c < "$vjar"),$COMMIT,$(date +%F)" >> "$csv"
echo "built vanilla $V -> sha256=$sha"
