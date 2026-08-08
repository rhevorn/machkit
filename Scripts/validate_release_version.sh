#!/bin/bash

set -euo pipefail

tag="${1:-${GITHUB_REF_NAME:-}}"

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid release tag: ${tag:-<empty>}. Expected vMAJOR.MINOR.PATCH." >&2
  exit 1
fi

tag_version="${tag#v}"
build_settings="$({
  xcodebuild \
    -project Sift.xcodeproj \
    -scheme "Sift App" \
    -configuration Release \
    -derivedDataPath build/XcodeDerivedData \
    CODE_SIGNING_ALLOWED=NO \
    -showBuildSettings
} 2>&1)" || {
  echo "$build_settings" >&2
  exit 1
}

marketing_version="$(printf '%s\n' "$build_settings" | awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }')"

if [[ -z "$marketing_version" ]]; then
  echo "Unable to read MARKETING_VERSION from Sift.xcodeproj." >&2
  exit 1
fi

if [[ "$tag_version" != "$marketing_version" ]]; then
  echo "Tag version $tag does not match MARKETING_VERSION $marketing_version" >&2
  exit 1
fi

printf '%s\n' "$tag_version"
