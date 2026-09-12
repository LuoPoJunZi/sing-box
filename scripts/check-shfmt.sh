#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
. "$ROOT_DIR/scripts/tool-versions.sh"

if ! command -v shfmt > /dev/null 2>&1; then
    echo "shfmt not found. Please install shfmt first."
    exit 1
fi

actual_version=$(shfmt --version 2> /dev/null)
actual_version=${actual_version#v}
actual_version=${actual_version%$'\r'}
if [[ $actual_version != "$SHFMT_VERSION" ]]; then
    echo "[shfmt] required version: $SHFMT_VERSION; found: ${actual_version:-unknown}"
    echo "[shfmt] see CONTRIBUTING.md for the local/CI tool baseline"
    exit 1
fi
echo "[shfmt] version: $actual_version"

shfmt -d -i 4 -ci -sr install.sh sing-box.sh src scripts tests
echo "[shfmt] ok"
