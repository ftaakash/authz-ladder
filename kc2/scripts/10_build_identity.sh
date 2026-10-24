#!/usr/bin/env bash
# Build the KC2 identity-stack fat jars (IdentityHub + IssuerService) from released
# Maven Central BOMs, inside the pinned gradle container (host JVM has no loopback — see
# KC1 30_build_vanilla.sh). Build has egress; the runtime testbed network stays internal.
# Usage: ./10_build_identity.sh            (builds both roles at the pinned EDC 0.17.0)
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"  # gradle:8.10-jdk21, logged in ENV.md
SRC="$PILOT/kc2/identity"; V="${EDC_V:-0.17.0}"
csv="$PILOT/kc2/env/identity-jars.csv"; [ -f "$csv" ] || echo "role,edc_version,sha256,bytes,commit,date" > "$csv"
for role in identityhub issuer; do
  MSYS_NO_PATHCONV=1 docker run --rm -v "$SRC":/work -w /work \
    -v pilot08-gradle-cache:/home/gradle/.gradle \
    "$GRADLE_IMG" gradle --console=plain --no-daemon shadowJar -Prole="$role" -Pedc="$V"
  jar="$SRC/build/libs/pilot08kc2-${role}-all.jar"
  [ -f "$jar" ] || { echo "build failed: no $role jar"; exit 1; }
  rjar="$SRC/build/libs/pilot08kc2-${role}-${V}.jar"; cp "$jar" "$rjar"
  sha="$(sha256sum "$rjar" | cut -d' ' -f1)"
  grep -qE "^$role,$V,$sha,[0-9]+,$COMMIT," "$csv" || echo "$role,$V,$sha,$(wc -c < "$rjar"),$COMMIT,$(date +%F)" >> "$csv"
  echo "built $role $V -> sha256=$sha"
done
cat "$csv"
