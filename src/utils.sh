#!/bin/bash
# ==========================================
# Sing-box-EV Utility Toolbox
# ==========================================

load_lib() {
    local lib_name
    for lib_name in manifest fs json systemd firewall net crypto version download tunnel; do
        . "$is_sh_dir/src/lib/${lib_name}.sh"
    done
}

load_runtime_utils() {
    local util_name
    for util_name in download bbr log dns compat; do
        . "$is_sh_dir/src/core/utils/${util_name}.sh"
    done
}

load_lib
load_runtime_utils
unset -f load_lib load_runtime_utils
