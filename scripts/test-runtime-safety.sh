#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

is_sh_dir="$tmp_dir/sh"
is_config_json="$tmp_dir/missing-config.json"
is_conf_dir="$tmp_dir/missing-conf"
is_caddy_dir="$tmp_dir/caddy"
is_caddy_conf="$is_caddy_dir/managed"
is_core_ver=test-core
is_sh_ver=test-script
is_gen=
is_test_json=
is_disable_snapshot=
is_snapshot_id=
is_dry_run=
is_caddy=
is_dont_auto_exit=1

msg() { :; }
warn() { :; }
_green() { printf '%s' "$*"; }
err() {
    echo "[runtime-safety] $*" >&2
    return 1
}

. src/core/runtime/snapshot.sh
. src/core/runtime/rollback.sh

runtime_snapshot_ensure '../../outside|unsafe\name'
[[ $is_snapshot_id != */* ]] || {
    echo "[runtime-safety] snapshot id contains path separator"
    exit 1
}
[[ $is_snapshot_id != *'|'* && $is_snapshot_id != *'\'* ]] || {
    echo "[runtime-safety] snapshot id contains unsafe delimiter"
    exit 1
}
[[ -d $is_sh_dir/backups/$is_snapshot_id ]] || {
    echo "[runtime-safety] normalized snapshot was not created"
    exit 1
}

if runtime_snapshot_restore '../outside' > /dev/null 2>&1; then
    echo "[runtime-safety] rollback accepted path traversal"
    exit 1
fi

echo "[runtime-safety] ok"
