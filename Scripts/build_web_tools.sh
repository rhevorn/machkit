#!/bin/sh

set -eu

project_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
tool_root="$project_root/Tool"
output_root="$project_root/Resources/WebTools"

npm_path="$(command -v npm || true)"
if [ -z "$npm_path" ]; then
    for candidate in "$HOME"/.nvm/versions/node/*/bin/npm /opt/homebrew/bin/npm /usr/local/bin/npm; do
        if [ -x "$candidate" ]; then
            npm_path="$candidate"
        fi
    done
fi

if [ -z "$npm_path" ]; then
    echo "error: npm was not found. Install Node.js before building MachKit." >&2
    exit 1
fi

PATH="$(dirname "$npm_path"):$PATH"
export PATH

stamp_path="$output_root/.machkit-build-input.sha256"
input_hash="$({
    find "$tool_root/src" "$tool_root/tools" -type f -print
    printf '%s\n' "$tool_root/index.html" "$tool_root/package.json" "$tool_root/package-lock.json" "$tool_root/vite.config.mjs"
} | LC_ALL=C sort | while IFS= read -r input_path; do
    shasum -a 256 "$input_path"
done | shasum -a 256 | awk '{print $1}')"

if [ -f "$stamp_path" ] &&
   [ -f "$output_root/tools/timestamp-converter/index.html" ] &&
   [ "$(cat "$stamp_path")" = "$input_hash" ]; then
    echo "MachKit H5 tools are up to date."
    exit 0
fi

if [ ! -d "$tool_root/node_modules" ]; then
    echo "Installing locked H5 tool dependencies…"
    cd "$tool_root"
    "$npm_path" ci
fi

cd "$tool_root"
"$npm_path" run build:app

if [ ! -f "$output_root/tools/timestamp-converter/index.html" ]; then
    echo "error: H5 tool build completed without the timestamp converter output." >&2
    exit 1
fi

printf '%s\n' "$input_hash" > "$stamp_path"
