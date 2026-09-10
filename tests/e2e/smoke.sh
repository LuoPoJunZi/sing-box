#!/usr/bin/env bash
set -euo pipefail

SB_BIN="${SB_BIN:-sb}"

if ! command -v "$SB_BIN" > /dev/null 2>&1; then
    echo "[smoke] command not found: $SB_BIN"
    echo "[smoke] set SB_BIN=sing-box or install alias first"
    exit 1
fi

echo "[smoke] using command: $SB_BIN"

run() {
    echo
    echo "[smoke] >>> $*"
    "$@"
}

# Read-only smoke checks (safe for production hosts)
readonly_checks=(
    help
    version
    status
    doctor
    "backup list"
    "domain list"
)

for check in "${readonly_checks[@]}"; do
    # shellcheck disable=SC2086
    run "$SB_BIN" $check
done

echo
echo "[smoke] basic checks passed"
