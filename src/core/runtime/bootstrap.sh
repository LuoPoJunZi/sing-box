#!/bin/bash

# Mutating prerequisites belong to explicit write operations, never init/query.
runtime_ensure_tls() (
    [[ -s $is_tls_cer && -s $is_tls_key ]] && return 0
    if [[ ${is_dry_run:-} ]]; then
        msg "DRY-RUN: 将生成缺失的 TLS 证书和私钥"
        return 0
    fi
    umask 077
    local stage lock="${is_tls_key%/*}/.tls.lock"
    mkdir -- "$lock" 2> /dev/null || {
        warn "TLS 初始化正在执行，请稍后重试"
        return 1
    }
    trap 'rmdir -- "$lock"' EXIT
    [[ -s $is_tls_cer && -s $is_tls_key ]] && return 0
    if [[ -e $is_tls_cer || -e $is_tls_key ]]; then
        warn "TLS 文件不完整，请从备份恢复匹配的证书和私钥；不会自动覆盖现有指纹"
        return 1
    fi
    stage=$(mktemp -d "${is_tls_key%/*}/.tls-XXXXXX") || return 1
    trap 'rm -rf -- "$stage"; rmdir -- "$lock"' EXIT
    "$is_core_bin" generate tls-keypair tls -m 456 > "$stage/bundle" 2> /dev/null || return 1
    awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' "$stage/bundle" > "$stage/key"
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$stage/bundle" > "$stage/cert"
    [[ -s $stage/key && -s $stage/cert ]] || return 1
    mv -f -- "$stage/key" "$is_tls_key" || return 1
    mv -f -- "$stage/cert" "$is_tls_cer" || {
        rm -f -- "$is_tls_key"
        return 1
    }
)

runtime_repair_caddy_service() {
    [[ -f /lib/systemd/system/caddy.service ]] || return 0
    if ! grep -q -- '--adapter caddyfile' /lib/systemd/system/caddy.service; then
        install_service caddy || return 1
    fi
}
