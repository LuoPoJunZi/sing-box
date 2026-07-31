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

create_cftunnel_service() {
    local token=$1
    local l_port=$2
    cat << EOF > /lib/systemd/system/cftunnel-${l_port}.service
[Unit]
Description=Cloudflare Tunnel for Port ${l_port}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${token}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now cftunnel-${l_port}.service &> /dev/null
    managed_record service "cftunnel-${l_port}.service"
    managed_record file "/lib/systemd/system/cftunnel-${l_port}.service"
    msg "✅ CFtunnel 穿透守护服务 (关联内部端口: ${l_port}) 已创建并启动."
    msg "⚠️  $(_yellow "重要：别忘了去 Cloudflare 面板完成域名映射！")"
}
