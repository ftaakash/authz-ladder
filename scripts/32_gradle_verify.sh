#!/usr/bin/env bash
# D1 / D8: Gradle dependency verification for the KC1 launcher, so SCOPE.md's
# "dependencies checksum-verified" is true. Not trust-on-first-use: every recorded
# checksum is cross-checked against the publisher's own .sha1, then enforced strictly,
# then a tamper negative-control proves enforcement works.
# Checksum-only (sha1+sha256); PGP is skipped (needs keyserver downloads = a new source).
# Usage: ./32_gradle_verify.sh
source "$(dirname "$0")/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
SRC="$PILOT/testbed/launcher"; CACHE="pilot08-gradle-cache"
XML="$SRC/gradle/verification-metadata.xml"
VERS="0.6.2 0.6.3 0.9.0 0.9.1"
gb() { MSYS_NO_PATHCONV=1 docker run --rm -v "$SRC":/work -w /work -v "$CACHE":/home/gradle/.gradle "$GRADLE_IMG" gradle --no-daemon --console=plain "$@"; }

echo "== (a) bootstrap verification-metadata (sha1,sha256) =="
rm -f "$XML"
for V in $VERS; do echo "  write-metadata $V"; gb --write-verification-metadata sha1,sha256 shadowJar -Pedc="$V" >/dev/null 2>&1 || { echo "bootstrap build failed $V"; exit 1; }; done
[ -f "$XML" ] || { echo "no verification-metadata.xml produced"; exit 1; }
recorded="$(grep -c '<artifact ' "$XML")"; echo "  artifacts recorded: $recorded"

echo "== (b) cross-check each artifact's sha1 against the publisher (inside a curl container) =="
# emit: group name version artifactfile sha1  — parsed from the gradle XML
awk '
  /<component / { if (match($0,/group="[^"]*"/)) {g=substr($0,RSTART+7,RLENGTH-8)};
                  if (match($0,/name="[^"]*"/)) {n=substr($0,RSTART+6,RLENGTH-7)};
                  if (match($0,/version="[^"]*"/)) {v=substr($0,RSTART+9,RLENGTH-10)} }
  /<artifact / { if (match($0,/name="[^"]*"/)) {a=substr($0,RSTART+6,RLENGTH-7)} }
  /<sha1 / { if (match($0,/value="[^"]*"/)) {s=substr($0,RSTART+7,RLENGTH-8); print g" "n" "v" "a" "s} }
' "$XML" > "$PILOT/build/verify-list.txt"
total="$(wc -l < "$PILOT/build/verify-list.txt" | tr -d ' ')"; echo "  sha1 entries to cross-check: $total"
# cross-check runs in pilot08/curl (curl+awk+sh); mount the build DIR (single-file mounts are
# unreliable on this Docker host) and disable MSYS path conversion of the container paths.
mism="$(MSYS_NO_PATHCONV=1 docker run --rm -v "$PILOT/build":/b:ro pilot08/curl:8.11.1 sh -c '
  m=0; miss=0; n=0;
  while read g name ver art sha; do
    n=$((n+1)); path=$(echo "$g" | tr "." "/");
    # The recorded checksum must match the publisher Gradle actually resolved the artifact from.
    # EDC artifacts come from Maven Central and MUST match there. The Gradle Plugin Portal hosts a
    # DIFFERENT pom than Central at the same coordinates, so it is accepted as a publisher ONLY for
    # the shadow plugin + its marker (group com.gradleup.shadow*, L6); for every other artifact a
    # Portal-only match is NOT accepted and counts as a real mismatch.
    c=$(curl -s --max-time 15 "https://repo1.maven.org/maven2/$path/$name/$ver/$art.sha1" | tr -d " \r\n\t");
    [ "$c" = "$sha" ] && continue;
    p="";
    case "$g" in com.gradleup.shadow*) p=$(curl -s --max-time 15 "https://plugins.gradle.org/m2/$path/$name/$ver/$art.sha1" | tr -d " \r\n\t"); [ "$p" = "$sha" ] && continue;; esac;
    if [ -z "$c" ] && [ -z "$p" ]; then miss=$((miss+1)); echo "MISSING $g:$name:$ver:$art" >&2;
    else m=$((m+1)); echo "MISMATCH $g:$name:$ver:$art recorded=$sha central=${c:-none} portal=${p:-none}" >&2; fi
  done < /b/verify-list.txt
  echo "checked=$n mismatch=$m missing=$miss"
' 2>"$PILOT/build/verify-crosscheck.err")"
echo "  $mism"; head -8 "$PILOT/build/verify-crosscheck.err" 2>/dev/null
checked="$(echo "$mism" | grep -oE 'checked=[0-9]+' | cut -d= -f2)"
mcount="$(echo "$mism" | grep -oE 'mismatch=[0-9]+' | cut -d= -f2)"; misscount="$(echo "$mism" | grep -oE 'missing=[0-9]+' | cut -d= -f2)"
# a real cross-check requires EVERY recorded entry to have been checked against the publisher.
crosscheck_ok=yes
{ [ "${checked:-0}" != "$total" ] || [ "${mcount:-1}" != 0 ] || [ "${misscount:-1}" != 0 ]; } && crosscheck_ok=no
if [ "$crosscheck_ok" != yes ]; then echo "CROSS-CHECK FAILED (checked=$checked/$total mismatch=$mcount missing=$misscount) — see build/verify-crosscheck.err; STOPPING, not regenerating."; fi

echo "== (c) enforce: strict rebuild all four (no --write) =="
enforce_ok=yes
for V in $VERS; do gb shadowJar -Pedc="$V" >/dev/null 2>&1 || { echo "  strict build FAILED $V"; enforce_ok=no; }; done
echo "  strict builds ok: $enforce_ok"

echo "== (d) negative control: tamper a COPY, expect a verification failure =="
tamper_detected=no; tmp="$(mktemp -d)"; cp -r "$SRC"/. "$tmp"/ 2>/dev/null
# flip the first sha256 hex char in the copy's XML
perl -0pi -e 's/(<sha256 value=")([0-9a-f])/$1 . (($2 eq "a")?"b":"a")/e' "$tmp/gradle/verification-metadata.xml" 2>/dev/null
if MSYS_NO_PATHCONV=1 docker run --rm -v "$tmp":/work -w /work -v "$CACHE":/home/gradle/.gradle "$GRADLE_IMG" gradle --no-daemon --console=plain shadowJar -Pedc=0.6.2 >/dev/null 2>&1; then tamper_detected=no; else tamper_detected=yes; fi
rm -rf "$tmp"; echo "  tamper detected: $tamper_detected"

echo "== (e) record env/gradle-verification.csv =="
out="$PILOT/env/gradle-verification.csv"; echo "edc_version,build_ok,artifacts_recorded,sha1_checked,sha1_crosscheck_ok,sha1_mismatches,sha1_missing,tamper_detected,commit" > "$out"
for V in $VERS; do echo "$V,$enforce_ok,$recorded,${checked:-0},$crosscheck_ok,${mcount:-NA},${misscount:-NA},$tamper_detected,$COMMIT" >> "$out"; done
cat "$out"
[ "$crosscheck_ok" = yes ] && [ "$enforce_ok" = yes ] && [ "$tamper_detected" = yes ] && echo "VERIFICATION OK" || { echo "VERIFICATION INCOMPLETE"; exit 1; }
