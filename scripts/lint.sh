#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[lint] shellcheck"
bash scripts/check-shell.sh
echo "[lint] shfmt"
bash scripts/check-shfmt.sh
bash scripts/check-structure.sh
bash scripts/check-repo-hygiene.sh
bash scripts/check-share-links.sh
bash scripts/check-release.sh
bash scripts/test.sh
echo "[lint] done"
