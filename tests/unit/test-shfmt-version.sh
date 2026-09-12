#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. scripts/tool-versions.sh

# Mock only this child's tool discovery/version; do not run the formatter here.
shfmt() {
    if [[ $1 == --version ]]; then
        printf 'v%s\r\n' "$TEST_SHFMT_VERSION"
    elif [[ $TEST_SHFMT_VERSION != "$SHFMT_VERSION" ]]; then
        echo 'UNEXPECTED_FILE_SCAN'
        return 1
    fi
}
export -f shfmt
export SHFMT_VERSION
for version in 3.8.0 3.14.0 unknown; do
    if output=$(TEST_SHFMT_VERSION=$version bash scripts/check-shfmt.sh 2>&1); then
        echo "[shfmt-version] accepted mismatched version: $version"
        exit 1
    fi
    [[ $output == *"required version: $SHFMT_VERSION"* && $output != *UNEXPECTED_FILE_SCAN* ]]
done
output=$(TEST_SHFMT_VERSION=$SHFMT_VERSION bash scripts/check-shfmt.sh)
[[ $output == *'[shfmt] ok'* ]]
echo '[shfmt-version] ok: version drift rejected, matching version and CRLF supported'
