#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v shfmt > /dev/null 2>&1; then
    echo "shfmt not found. Please install shfmt first."
    exit 1
fi

echo "[lint] shellcheck"
bash scripts/check-shell.sh

echo "[lint] installer cli"
bash scripts/test-install-cli.sh

echo "[lint] command dispatch"
bash scripts/test-dispatch.sh

echo "[lint] runtime safety"
bash scripts/test-runtime-safety.sh

echo "[lint] shfmt"
shfmt -d -i 4 -ci -sr install.sh sing-box.sh src scripts

echo "[lint] structure"
scripts/check-structure.sh

echo "[lint] share links"
bash scripts/check-share-links.sh

echo "[lint] share output"
bash scripts/test-share-output.sh

echo "[lint] release"
bash scripts/check-release.sh

echo "[lint] regression script syntax"
bash -n scripts/regression-cli.sh

echo "[lint] done"
