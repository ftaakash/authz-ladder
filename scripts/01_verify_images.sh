#!/usr/bin/env bash
# Verify each local rung against its pinned digest and record which CVE-relevant
# classes its runtime jar contains. Output: env/image-check.csv (environment
# evidence, not test results).
source "$(dirname "$0")/lib.sh"
out="$PILOT/env/image-check.csv"; tmp="$(mktemp -d)"
echo "rung,tx_tag,edc_version,digest_match,classes,DatasetResolverImpl,DatasetFixExtension,ConsumerPullTransferTokenValidation,dpf_oauth2,commit" > "$out"
pins | while IFS=$'\t' read -r rung tag edc image digest jar; do
  img="$(local_tag "$tag")"
  match=no; docker image inspect "$img" --format '{{join .RepoDigests " "}}' | grep -q "$digest" && match=yes
  c="$(docker create "$img")"; docker cp -q "$c:$jar" "$tmp/$tag.jar"; docker rm "$c" >/dev/null
  jar tf "$tmp/$tag.jar" > "$tmp/$tag.lst"
  n() { grep -cE "$1" "$tmp/$tag.lst" || true; }
  echo "$rung,$tag,$edc,$match,$(n '\.class$'),$(n 'DatasetResolverImpl\.class$'),$(n 'DatasetFixExtension\.class$'),$(n 'ConsumerPullTransferTokenValidation'),$(n 'dataplane/http/oauth2|Oauth2DataAddress|oauth2/Oauth2'),$COMMIT" >> "$out"
done
rm -rf "$tmp"; cat "$out"
