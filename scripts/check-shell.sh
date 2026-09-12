#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
. "$ROOT_DIR/scripts/tool-versions.sh"

if ! command -v shellcheck > /dev/null 2>&1; then
    echo "shellcheck not found. Please install shellcheck first."
    exit 1
fi

actual_version=$(shellcheck --version | awk '/^version:/ {print $2}')
actual_version=${actual_version%$'\r'}
if [[ $actual_version != "$SHELLCHECK_VERSION" ]]; then
    echo "[shellcheck] required version: $SHELLCHECK_VERSION; found: ${actual_version:-unknown}"
    echo "[shellcheck] see CONTRIBUTING.md for the local/CI tool baseline"
    exit 1
fi
echo "[shellcheck] version: $actual_version"

while IFS= read -r -d '' file; do
    shellcheck_args=(-S warning)
    if [[ $file == ./install.sh ]]; then
        mode="standalone"
    else
        mode="module"
        shellcheck_args+=(-e "SC1090,SC2034,SC2154")
    fi
    echo "shellcheck ($mode): $file"
    shellcheck "${shellcheck_args[@]}" "$file"
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print0)

echo "[shellcheck] ok"
