#!/usr/bin/env bash
# KC2: pull the pinned Tractus-X target image by digest, retag it locally, and record
# digest match + runtime jar sha256 in kc2/env/targets.csv. Idempotent. Build/pull step only.
source "$(dirname "$0")/../../scripts/lib.sh"
K2="$PILOT/kc2"; out="$K2/env/targets.csv"; tmp="$(mktemp -d)"
echo "name,version,bundled_edc,digest,digest_match,runtime_jar,jar_sha256,classes,commit" > "$out"
grep -v '^#' "$K2/pins.tsv" | awk -F'\t' '$1=="image"' | while IFS=$'\t' read -r kind name ver edc src digest; do
  docker pull -q "$name@$digest" >/dev/null
  loc="pilot08k2/$(basename "$name"):$ver"; docker tag "$name@$digest" "$loc"
  match=no; docker image inspect "$loc" --format '{{join .RepoDigests " "}}' | grep -q "$digest" && match=yes
  c="$(docker create "$loc")"
  jar="$(docker export "$c" | tar -t 2>/dev/null | grep -E '^app/.*\.jar$' | head -1)"
  docker cp -q "$c:/$jar" "$tmp/rt.jar"; docker rm "$c" >/dev/null
  sha="$(sha256sum "$tmp/rt.jar" | cut -d' ' -f1)"; n="$(unzip -l "$tmp/rt.jar" | grep -c '\.class$' || true)"
  echo "$name,$ver,$edc,$digest,$match,/$jar,$sha,$n,$COMMIT" >> "$out"
done
rm -rf "$tmp"; cat "$out"
