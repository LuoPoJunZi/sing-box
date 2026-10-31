#!/bin/bash

install_service() {
    case $1 in
        "$is_core")
            cat > /lib/systemd/system/$is_core.service <<< "
[Unit]
Description=$is_core_name Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=$is_core_bin run -c $is_config_json -C $is_conf_dir
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target"
            ;;
        caddy)
            cat > /lib/systemd/system/caddy.service <<< "
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --environ --config $is_caddyfile --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
TimeoutStopSec=5s
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target"
            ;;
    esac
    systemctl enable "$1" > /dev/null 2>&1
    systemctl daemon-reload > /dev/null 2>&1
}

cftunnel_systemd_dir() {
    printf '%s\n' /lib/systemd/system
}

cftunnel_token_path() {
    local l_port=$1

    [[ $l_port =~ ^[1-9][0-9]{0,4}$ ]] && ((l_port <= 65535)) || return 1
    [[ ${is_core_dir:-} == /* && $is_core_dir != / ]] || return 1
    printf '%s/cftunnel/%s.token\n' "${is_core_dir%/}" "$l_port"
}

cftunnel_unit_content() {
    local l_port=$1 token_file=$2

    # Only validated script-owned paths reach this renderer. Escape systemd's
    # percent specifiers and quote paths (including paths in test fixtures).
    token_file=${token_file//%/%%}
    token_file=${token_file//\\/\\\\}
    token_file=${token_file//\"/\\\"}
    cat << EOF
[Unit]
Description=Cloudflare Tunnel for Port ${l_port}
After=network.target

[Service]
Type=simple
UMask=0077
NoNewPrivileges=true
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate --metrics 127.0.0.1:0 run --token-file "${token_file}"
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

cftunnel_create_preflight() {
    local token=$1 l_port=$2 token_file token_dir unit_file unit_name

    token_file=$(cftunnel_token_path "$l_port") || return 1
    [[ $token =~ ^[A-Za-z0-9_/+=-]+$ && $token_file != *$'\n'* && $token_file != *$'\r'* ]] || {
        msg "CFtunnel 参数无效；未写入凭据或服务."
        return 1
    }
    unit_name="cftunnel-${l_port}.service"
    unit_file="$(cftunnel_systemd_dir)/$unit_name"
    token_dir=${token_file%/*}
    # Never silently migrate/restart an existing service, nor follow a token
    # directory/file symlink. Existing installations are diagnosed read-only.
    if [[ -e $unit_file || -L $unit_file || -e /etc/systemd/system/$unit_name ||
        -L /etc/systemd/system/$unit_name || -e $token_file || -L $token_file || -L $token_dir ]]; then
        msg "CFtunnel 服务或凭据已存在；未覆盖或重启，请在维护窗口检查."
        return 1
    fi
    return 0
}

create_cftunnel_service() {
    local token=$1 l_port=$2 token_file token_dir unit_file unit_name

    cftunnel_create_preflight "$token" "$l_port" || return 1
    token_file=$(cftunnel_token_path "$l_port") || return 1
    token_dir=${token_file%/*}
    unit_name="cftunnel-${l_port}.service"
    unit_file="$(cftunnel_systemd_dir)/$unit_name"
    (umask 077 && mkdir -p -- "$token_dir" && chmod 700 -- "$token_dir") || return 1
    # noclobber prevents overwriting an intervening file/symlink. No token is
    # passed as an external command argument or printed to diagnostics.
    (
        umask 077
        set -o noclobber
        printf '%s\n' "$token" > "$token_file"
    ) || return 1
    if ! (
        umask 022
        set -o noclobber
        : > "$unit_file"
    ); then
        rm -f -- "$token_file"
        return 1
    fi
    if ! cftunnel_unit_content "$l_port" "$token_file" > "$unit_file"; then
        rm -f -- "$unit_file" "$token_file"
        return 1
    fi
    if ! systemctl daemon-reload || ! systemctl enable --now "$unit_name" > /dev/null 2>&1 ||
        ! systemctl is-active --quiet "$unit_name"; then
        systemctl disable --now "$unit_name" > /dev/null 2>&1 || true
        rm -f -- "$unit_file" "$token_file"
        systemctl daemon-reload > /dev/null 2>&1 || true
        msg "CFtunnel 服务启动失败，已清理本次创建的服务和凭据."
        return 1
    fi
    managed_record dir "$token_dir"
    managed_record file "$token_file"
    managed_record service "$unit_name"
    managed_record file "$unit_file"
    msg "✅ CFtunnel 穿透守护服务 (关联内部端口: ${l_port}) 已创建并启动."
    msg "⚠️  $(_yellow "重要：别忘了去 Cloudflare 面板完成域名映射！")"
}

remove_cftunnel_token() {
    local token_file

    token_file=$(cftunnel_token_path "$1") || return 1
    [[ ! -L ${token_file%/*} ]] || return 1
    rm -f -- "$token_file"
}
