#!/usr/bin/env bash
# KC2: Gradle dependency verification for the kc2/identity launcher (IdentityHub + IssuerService),
# mirroring scripts/32_gradle_verify.sh (D1/D8): record sha1+sha256, cross-check every sha1 against
# the publisher's own .sha1 (Maven Central; Gradle Plugin Portal accepted ONLY for the shadow plugin),
# enforce strict builds, then a tamper negative control. Checksum-only (PGP skipped — keyserver = new source).
# Usage: ./12_gradle_verify_identity.sh
source "$(dirname "$0")/../../scripts/lib.sh"
GRADLE_IMG="gradle@sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba"
SRC="$PILOT/kc2/identity"; CACHE="pilot08-gradle-cache"; V="${EDC_V:-0.17.0}"
XML="$SRC/gradle/verification-metadata.xml"; ROLES="identityhub issuer"
mkdir -p "$PILOT/build"
gb() { MSYS_NO_PATHCONV=1 docker run --rm -v "$SRC":/work -w /work -v "$CACHE":/home/gradle/.gradle "$GRADLE_IMG" gradle --no-daemon --console=plain "$@"; }

echo "== (a) bootstrap verification-metadata (sha1,sha256) for both roles =="
rm -f "$XML"
for r in $ROLES; do echo "  write-metadata $r"; gb --write-verification-metadata sha1,sha256 shadowJar -Prole="$r" -Pedc="$V" >/dev/null 2>&1 || { echo "bootstrap build failed $r"; exit 1; }; done
[ -f "$XML" ] || { echo "no verification-metadata.xml produced"; exit 1; }
recorded="$(grep -c '<artifact ' "$XML")"; echo "  artifacts recorded: $recorded"

echo "== (b) cross-check each artifact's sha1 against the publisher =="
awk '
  /<component / { if (match($0,/group="[^"]*"/)) {g=substr($0,RSTART+7,RLENGTH-8)};
                  if (match($0,/name="[^"]*"/)) {n=substr($0,RSTART+6,RLENGTH-7)};
                  if (match($0,/version="[^"]*"/)) {v=substr($0,RSTART+9,RLENGTH-10)} }
  /<artifact / { if (match($0,/name="[^"]*"/)) {a=substr($0,RSTART+6,RLENGTH-7)} }
  /<sha1 / { if (match($0,/value="[^"]*"/)) {s=substr($0,RSTART+7,RLENGTH-8); print g" "n" "v" "a" "s} }
' "$XML" > "$PILOT/build/kc2-verify-list.txt"
total="$(wc -l < "$PILOT/build/kc2-verify-list.txt" | tr -d ' ')"; echo "  sha1 entries to cross-check: $total"
mism="$(MSYS_NO_PATHCONV=1 docker run --rm -v "$PILOT/build":/b:ro pilot08/curl:8.11.1 sh -c '
  m=0; miss=0; n=0;
  while read g name ver art sha; do
    n=$((n+1)); path=$(echo "$g" | tr "." "/");
    c=$(curl -s --max-time 15 "https://repo1.maven.org/maven2/$path/$name/$ver/$art.sha1" | tr -d " \r\n\t");
    [ "$c" = "$sha" ] && continue;
    p="";
    case "$g" in com.gradleup.shadow*) p=$(curl -s --max-time 15 "https://plugins.gradle.org/m2/$path/$name/$ver/$art.sha1" | tr -d " \r\n\t"); [ "$p" = "$sha" ] && continue;; esac;
    if [ -z "$c" ] && [ -z "$p" ]; then miss=$((miss+1)); echo "MISSING $g:$name:$ver:$art" >&2;
    else m=$((m+1)); echo "MISMATCH $g:$name:$ver:$art recorded=$sha central=${c:-none} portal=${p:-none}" >&2; fi
  done < /b/kc2-verify-list.txt
  echo "checked=$n mismatch=$m missing=$miss"
' 2>"$PILOT/build/kc2-verify-crosscheck.err")"
echo "  $mism"; head -8 "$PILOT/build/kc2-verify-crosscheck.err" 2>/dev/null
checked="$(echo "$mism" | grep -oE 'checked=[0-9]+' | cut -d= -f2)"
mcount="$(echo "$mism" | grep -oE 'mismatch=[0-9]+' | cut -d= -f2)"; misscount="$(echo "$mism" | grep -oE 'missing=[0-9]+' | cut -d= -f2)"
crosscheck_ok=yes
{ [ "${checked:-0}" != "$total" ] || [ "${mcount:-1}" != 0 ] || [ "${misscount:-1}" != 0 ]; } && crosscheck_ok=no
[ "$crosscheck_ok" != yes ] && echo "CROSS-CHECK FAILED (checked=$checked/$total mismatch=$mcount missing=$misscount) — see build/kc2-verify-crosscheck.err; STOPPING."

echo "== (c) enforce: strict rebuild both roles (no --write) =="
enforce_ok=yes
for r in $ROLES; do gb shadowJar -Prole="$r" -Pedc="$V" >/dev/null 2>&1 || { echo "  strict build FAILED $r"; enforce_ok=no; }; done
echo "  strict builds ok: $enforce_ok"

echo "== (d) negative control: tamper a COPY, expect a verification failure =="
tamper_detected=no; tmp="$(mktemp -d)"; cp -r "$SRC"/. "$tmp"/ 2>/dev/null; rm -rf "$tmp/build" "$tmp/.gradle"
perl -0pi -e 's/(<sha256 value=")([0-9a-f])/$1 . (($2 eq "a")?"b":"a")/e' "$tmp/gradle/verification-metadata.xml" 2>/dev/null
if MSYS_NO_PATHCONV=1 docker run --rm -v "$tmp":/work -w /work -v "$CACHE":/home/gradle/.gradle "$GRADLE_IMG" gradle --no-daemon --console=plain shadowJar -Prole=identityhub -Pedc="$V" >/dev/null 2>&1; then tamper_detected=no; else tamper_detected=yes; fi
rm -rf "$tmp"; echo "  tamper detected: $tamper_detected"

echo "== (e) record kc2/env/gradle-verification.csv =="
out="$PILOT/kc2/env/gradle-verification.csv"; echo "launcher,edc_version,build_ok,artifacts_recorded,sha1_checked,sha1_crosscheck_ok,sha1_mismatches,sha1_missing,tamper_detected,commit" > "$out"
echo "kc2/identity,$V,$enforce_ok,$recorded,${checked:-0},$crosscheck_ok,${mcount:-NA},${misscount:-NA},$tamper_detected,$COMMIT" >> "$out"
cat "$out"
[ "$crosscheck_ok" = yes ] && [ "$enforce_ok" = yes ] && [ "$tamper_detected" = yes ] && echo "VERIFICATION OK" || { echo "VERIFICATION INCOMPLETE"; exit 1; }
