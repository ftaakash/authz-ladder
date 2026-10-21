#!/usr/bin/env bash
# Archive, per module, whether it is published on Maven Central at each ladder version.
# Covers every module the launcher uses (both the 0.6.x and 0.9.x sets) plus the
# vault-filesystem / auth-tokenbased modules needed by the F3/F5 fixtures.
# Output: env/maven-modules.csv. Reproducible; needs egress (metadata only).
source "$(dirname "$0")/lib.sh"
out="$PILOT/env/maven-modules.csv"
MODS="boot connector-core token-core control-plane-core dsp http iam-mock api-observability \
configuration-filesystem control-plane-api control-plane-api-client management-api management-api-configuration \
data-plane-selector-core data-plane-selector-api provision-http transfer-pull-http-dynamic-receiver \
policy-monitor-core data-plane-core data-plane-http data-plane-http-oauth2 data-plane-signaling-api \
data-plane-control-api transfer-data-plane \
control-api-configuration edr-store-core edr-cache-api edr-store-receiver callback-event-dispatcher \
callback-http-dispatcher transfer-data-plane-signaling data-plane-selector-control-api \
data-plane-self-registration data-plane-iam data-plane-public-api-v2 \
vault-filesystem auth-tokenbased"
echo "module,v0.6.2,v0.6.3,v0.9.0,v0.9.1,note" > "$out"
for m in $MODS; do
  meta=$(curl -s --max-time 15 "https://repo1.maven.org/maven2/org/eclipse/edc/$m/maven-metadata.xml")
  r=""
  for v in 0.6.2 0.6.3 0.9.0 0.9.1; do echo "$meta" | grep -q "<version>$v</version>" && r="$r,yes" || r="$r,no"; done
  note=""
  [ "$m" = "transfer-data-plane" ] && note="CVE-2024-8642 module; published through 0.8.1 (see maven-metadata); removed >=0.9.0 so its patched state is vacuous (D6)"
  echo "$m$r,$note" >> "$out"
done
column -t -s, "$out" | sed 's/  */ /g'
