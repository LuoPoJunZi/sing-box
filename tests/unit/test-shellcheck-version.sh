#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. scripts/tool-versions.sh

# Mock only this child's tool discovery/version; do not run the full linter here.
shellcheck() {
    if [[ $1 == --version ]]; then
        printf 'version: %s\r\n' "$TEST_SHELLCHECK_VERSION"
    elif [[ $TEST_SHELLCHECK_VERSION != "$SHELLCHECK_VERSION" ]]; then
        echo 'UNEXPECTED_FILE_SCAN'
        return 1
    fi
}
export -f shellcheck
export SHELLCHECK_VERSION
for version in 0.9.0 0.10.0 unknown; do
    if output=$(TEST_SHELLCHECK_VERSION=$version bash scripts/check-shell.sh 2>&1); then
        echo "[shellcheck-version] accepted mismatched version: $version"
        exit 1
    fi
    [[ $output == *"required version: $SHELLCHECK_VERSION"* && $output != *UNEXPECTED_FILE_SCAN* ]]
done
output=$(TEST_SHELLCHECK_VERSION=$SHELLCHECK_VERSION bash scripts/check-shell.sh)
[[ $output == *'[shellcheck] ok'* ]]
echo '[shellcheck-version] ok: version drift rejected, matching version and CRLF supported'
