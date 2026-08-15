#!/bin/bash

set -euo pipefail

current_tag="${1:-${GITHUB_REF_NAME:-}}"
output_file="${2:-release-notes.md}"

if [[ ! "$current_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid release tag: ${current_tag:-<empty>}. Expected vMAJOR.MINOR.PATCH." >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "refs/tags/$current_tag" >/dev/null; then
  echo "Release tag does not exist: ${current_tag:-<empty>}" >&2
  exit 1
fi

previous_tag="$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 "${current_tag}^" 2>/dev/null || true)"
if [[ -n "$previous_tag" ]]; then
  commit_range="${previous_tag}..${current_tag}"
  echo "Generating release notes for $commit_range" >&2
else
  commit_range="$current_tag"
  echo "No previous version tag found; generating release notes through $current_tag" >&2
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/machkit-release-notes.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

features="$temporary_directory/features"
fixes="$temporary_directory/fixes"
performance="$temporary_directory/performance"
improvements="$temporary_directory/improvements"
documentation="$temporary_directory/documentation"
other="$temporary_directory/other"
touch "$features" "$fixes" "$performance" "$improvements" "$documentation" "$other"

while IFS= read -r subject; do
  [[ -z "$subject" ]] && continue

  if [[ "$subject" =~ ^([A-Za-z]+)(\([^\)]*\))?(!)?:[[:space:]]*(.+)$ ]]; then
    commit_type="${BASH_REMATCH[1]}"
    description="${BASH_REMATCH[4]}"
    case "$commit_type" in
      feat) printf '%s\n' "- $description" >> "$features" ;;
      fix) printf '%s\n' "- $description" >> "$fixes" ;;
      perf) printf '%s\n' "- $description" >> "$performance" ;;
      refactor) printf '%s\n' "- $description" >> "$improvements" ;;
      docs) printf '%s\n' "- $description" >> "$documentation" ;;
      chore)
        if [[ "$description" =~ ^release([[:space:]]+MachKit)?[[:space:]]+v?[0-9]+\.[0-9]+\.[0-9]+$ ]] \
          || [[ "$description" =~ ^bump[[:space:]]+version ]]; then
          continue
        fi
        ;;
      test|style|ci) ;;
      *) printf '%s\n' "- $subject" >> "$other" ;;
    esac
  else
    printf '%s\n' "- $subject" >> "$other"
  fi
done < <(git log --format='%s' "$commit_range")

mkdir -p "$(dirname "$output_file")"
{
  echo "## What's Changed"
  echo

  has_user_facing_changes=false
  append_section() {
    local title="$1"
    local source_file="$2"
    if [[ -s "$source_file" ]]; then
      echo "### $title"
      echo
      cat "$source_file"
      echo
      has_user_facing_changes=true
    fi
  }

  append_section "New Features" "$features"
  append_section "Fixes" "$fixes"
  append_section "Performance" "$performance"
  append_section "Improvements" "$improvements"
  append_section "Documentation" "$documentation"
  append_section "Other Changes" "$other"

  if [[ "$has_user_facing_changes" == false ]]; then
    echo "- No user-facing changes."
    echo
  fi

  echo "## Installation"
  echo
  echo "1. Download the macOS ZIP file."
  echo "2. Extract it and move MachKit to Applications."
  echo "3. Open MachKit."
  echo "4. If macOS blocks the app, open System Settings → Privacy & Security and choose Open Anyway."
} > "$output_file"

echo "Release notes written to $output_file" >&2
