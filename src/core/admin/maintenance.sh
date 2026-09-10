#!/bin/bash

admin_install_caddy() {
    if [[ ${is_dry_run:-} ]]; then
        msg "DRY-RUN: 将安装 Caddy"
        return 0
    fi
    _green "\n安装 Caddy 实现自动配置 TLS.\n"
    download caddy || return 1
    install_service caddy &> /dev/null || return 1
    is_caddy=1
    _green "安装 Caddy 成功.\n"
}

admin_reinstall() {
    if [[ ${is_dry_run:-} ]]; then
        msg "DRY-RUN: 将卸载后重新安装脚本"
        return 0
    fi
    local install_script
    install_script=$(< "$is_sh_dir/install.sh") || return 1
    uninstall || return 1
    bash <<< "$install_script"
}
