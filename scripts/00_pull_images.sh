#!/usr/bin/env bash
# Pull every pinned rung by digest and tag it locally. Idempotent.
source "$(dirname "$0")/lib.sh"
pins | while IFS=$'\t' read -r rung tag edc image digest jar; do
  docker pull -q "$image@$digest" >/dev/null
  docker tag "$image@$digest" "$(local_tag "$tag")"
  echo "pulled $rung $tag $digest"
done
