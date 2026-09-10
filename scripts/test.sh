#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# Offline by default. The real-core and VPS tests have explicit entry points.
for test_file in tests/unit/test-*.sh tests/integration/test-*.sh; do
    [[ $test_file == */test-sing-box-release.sh ]] && continue
    echo "[test] $test_file"
    bash "$test_file"
done
for test_file in tests/e2e/*.sh; do bash -n "$test_file"; done
echo "[test] ok"
