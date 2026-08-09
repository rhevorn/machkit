#!/bin/bash

set -euo pipefail

tag="${1:-${GITHUB_REF_NAME:-}}"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid release tag: ${tag:-<empty>}. Expected vMAJOR.MINOR.PATCH." >&2
  exit 1
fi

tag_version="${tag#v}"
printf '%s\n' "$tag_version"
