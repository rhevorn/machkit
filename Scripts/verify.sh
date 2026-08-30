#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

run_in() {
  local directory="$1"
  shift
  echo "+ ($directory) $*"
  (cd "$directory" && "$@")
}

echo "Verifying MachKit from $repo_root"

run_in "$repo_root" node Scripts/verify_npm_registries.mjs

run_in "$repo_root" swift test

run_in "$repo_root/Tool" npm test
run_in "$repo_root/Tool" npm run typecheck
run_in "$repo_root/Tool" npm run build

if [[ "${MACHKIT_RUN_UI_TESTS:-0}" == "1" ]]; then
  run_in "$repo_root/Tool" npm run test:ui
else
  echo "Skipping Playwright UI smoke tests (set MACHKIT_RUN_UI_TESTS=1 to include them)."
fi

run_in "$repo_root/Website" npm test
run_in "$repo_root/Website" npm run typecheck
run_in "$repo_root/Website" npm run build

run_in "$repo_root" xcodebuild \
  -project MachKit.xcodeproj \
  -scheme "MachKit App" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath build/XcodeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

run_in "$repo_root" git diff --check

echo "MachKit verification passed."
