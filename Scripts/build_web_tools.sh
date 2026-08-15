#!/bin/sh

set -eu

project_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
tool_root="$project_root/Tool"
output_root="$project_root/Resources/WebTools"

if [ ! -d "$tool_root/node_modules" ]; then
    echo "error: H5 tool dependencies are missing. Run: cd Tool && npm install" >&2
    exit 1
fi

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

cd "$tool_root"
"$npm_path" run build:app

if [ ! -f "$output_root/tools/timestamp-converter/index.html" ]; then
    echo "error: H5 tool build completed without the timestamp converter output." >&2
    exit 1
fi
