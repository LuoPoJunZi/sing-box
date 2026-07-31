#!/bin/bash

install_cloudflared() {
    if ! command -v cloudflared > /dev/null 2>&1; then
        msg "正在下载并安装 Cloudflare Tunnel (cloudflared)..."
        local cf_arch="amd64"
        if [[ $(uname -m) =~ "aarch64" || $(uname -m) =~ "armv8" ]]; then
            cf_arch="arm64"
        fi
        wget -qO /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}
        chmod +x /usr/local/bin/cloudflared
        managed_record file /usr/local/bin/cloudflared
        msg "✅ Cloudflare Tunnel 安装完成."
    fi
}
