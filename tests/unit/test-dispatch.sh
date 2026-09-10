#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
    echo "[dispatch] $*"
    exit 1
}

captured_command=
captured_args=()
deleted_configs=()
is_del_host=
is_gen=
is_no_auto_tls=

capture() {
    captured_command=$1
    shift
    captured_args=("$@")
}

add() { capture add "$@"; }
fake_core() { capture core "$@"; }
del() { deleted_configs+=("$1"); }
manage() { :; }
update() { capture update "$@"; }

is_core_bin=fake_core
. src/core/admin/dispatch.sh

admin_dispatch_command add trojan 443 'p@ss word'
[[ $captured_command == add ]] || fail "add command not dispatched"
[[ ${#captured_args[@]} -eq 3 && ${captured_args[2]} == 'p@ss word' ]] || fail "add arguments lost their boundaries"

admin_dispatch_command pbk
[[ $captured_command == core ]] || fail "pbk did not call the core"
[[ ${#captured_args[@]} -eq 2 && ${captured_args[0]} == generate && ${captured_args[1]} == reality-keypair ]] || fail "pbk mapping changed"

admin_dispatch_command dd 'node one.json' 'node two.json'
wait
[[ ${#deleted_configs[@]} -eq 2 ]] || fail "multi-delete count changed"
[[ ${deleted_configs[0]} == 'node one.json' && ${deleted_configs[1]} == 'node two.json' ]] || fail "multi-delete split config names"

admin_dispatch_command update.sh
[[ $captured_command == update ]] || fail "script update not dispatched"
[[ ${#captured_args[@]} -eq 2 && ${captured_args[0]} == sh && -z ${captured_args[1]} ]] || fail "script update arguments changed"

echo "[dispatch] ok"
