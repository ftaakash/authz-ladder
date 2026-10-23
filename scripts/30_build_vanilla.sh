#!/usr/bin/env bash
# Build a vanilla-EDC + iam-mock connector fat jar for one ladder version, from the
# tracked launcher sources in testbed/launcher/. Runs the build INSIDE a pinned
# gradle container because the host JVM sees no loopback interface (gradle needs one).
# The build container has egress (Maven Central); the runtime testbed stays internal.
# Usage: ./30_build_vanilla.sh 0.6.2
source "$(dirname "$0")/lib.sh"
V="${1:?usage: 30_build_vanilla.sh <edc-version>}"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"  # gradle:8.10-jdk21, logged in ENV.md
SRC="$PILOT/testbed/launcher"
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$SRC":/work -w /work \
  -v pilot08-gradle-cache:/home/gradle/.gradle \
  "$GRADLE_IMG" gradle --console=plain --no-daemon shadowJar -Pedc="$V"
jar="$SRC/build/libs/pilot08-edc-launcher-all.jar"
[ -f "$jar" ] || { echo "build failed: no jar"; exit 1; }
# Record the fat-jar sha256 so every KC1 result ties to an exact binary (D6).
vjar="$SRC/build/libs/pilot08-edc-$V.jar"; cp "$jar" "$vjar"
sha="$(sha256sum "$vjar" | cut -d' ' -f1)"
# Append-only, keyed by (version, sha, commit): keeps prior jar rows (e.g. the ones the
# -9202 evidence cites) while recording each new build, so every result traces to its exact jar.
csv="$PILOT/env/vanilla-jars.csv"; [ -f "$csv" ] || echo "edc_version,sha256,bytes,commit,date" > "$csv"
grep -qE "^$V,$sha,[0-9]+,$COMMIT," "$csv" || echo "$V,$sha,$(wc -c < "$vjar"),$COMMIT,$(date +%F)" >> "$csv"
echo "built $V -> $vjar sha256=$sha"
