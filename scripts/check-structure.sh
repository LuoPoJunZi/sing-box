#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

check_file() {
    local file="$1"
    if [[ ! -f $file ]]; then
        echo "[structure] missing: $file"
        fail=1
    fi
}

check_source_targets() {
    local loader="$1"
    local target

    check_file "$loader"
    [[ -f $loader ]] || return

    while IFS= read -r target; do
        [[ -z $target ]] && continue
        check_file "$target"
    done < <(
        sed -nE 's#^[[:space:]]*\.[[:space:]]+"\$is_sh_dir/([^"]+)".*$#\1#p' "$loader"
    )
}

check_lib_targets() {
    local lib_line lib

    lib_line="$(sed -nE 's/.*for lib_name in ([^;]+); do.*/\1/p' src/utils.sh | head -n 1)"
    if [[ -z $lib_line ]]; then
        echo "[structure] unable to find src/utils.sh lib list"
        fail=1
        return
    fi

    for lib in $lib_line; do
        check_file "src/lib/${lib}.sh"
    done
}

check_runtime_util_targets() {
    local util_line util

    util_line="$(sed -nE 's/.*for util_name in ([^;]+); do.*/\1/p' src/utils.sh | head -n 1)"
    if [[ -z $util_line ]]; then
        echo "[structure] unable to find src/utils.sh runtime util list"
        fail=1
        return
    fi

    for util in $util_line; do
        check_file "src/core/utils/${util}.sh"
    done
}

check_admin_dispatch_split() {
    if ! grep -q '^admin_dispatch_command()' src/core/admin/dispatch.sh; then
        echo "[structure] missing admin_dispatch_command in src/core/admin/dispatch.sh"
        fail=1
    fi

    if ! grep -q '^admin_menu_run_main_action()' src/core/admin/menu_actions.sh; then
        echo "[structure] missing admin_menu_run_main_action in src/core/admin/menu_actions.sh"
        fail=1
    fi

    if grep -Eq '^[[:space:]]*[0-9]+\)[[:space:]]*(add|change|info|del|manage|cron_task|uninstall|gen_sub|show_all_nodes|_try_enable_bbr|log_set|get |dns_set|update |doctor|backup_list|snapshot_ensure|rollback|about)' src/core/admin/menu.sh; then
        echo "[structure] menu.sh should route actions through menu_actions/dispatch, not call business functions directly"
        fail=1
    fi
}

check_source_targets src/core.sh
check_source_targets src/core/node/add.sh
check_source_targets src/core/node/change.sh
check_lib_targets
check_runtime_util_targets
check_admin_dispatch_split

# Source-only modules must not drift back into write-side preparation.
if grep -Eq 'node_prepare_protocol|install_service|systemctl[[:space:]]+(start|restart)|admin_reinstall' src/core/query/*.sh; then
    echo "[structure] query modules must not perform write-side preparation"
    fail=1
fi
for module in output system compat clients run; do
    check_file "src/core/runtime/doctor/$module.sh"
done
for test_group in unit integration e2e fixtures; do
    if [[ ! -d tests/$test_group ]]; then
        echo "[structure] missing test group: $test_group"
        fail=1
    fi
done

if [[ $fail -ne 0 ]]; then
    echo "[structure] failed"
    exit 1
fi

echo "[structure] ok"
