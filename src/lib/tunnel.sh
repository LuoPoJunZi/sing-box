#!/bin/bash

install_cloudflared() {
    if ! command -v cloudflared > /dev/null 2>&1; then
        msg "正在下载并安装 Cloudflare Tunnel (cloudflared)..."
        local cf_arch="amd64" tmp_dir metadata latest asset candidate
        if [[ $(uname -m) =~ "aarch64" || $(uname -m) =~ "armv8" ]]; then
            cf_arch="arm64"
        fi
        tmp_dir=$(mktemp -d 2> /dev/null || mktemp -d -t 'cloudflared-XXXXXX')
        metadata="$tmp_dir/release.json"
        candidate="$tmp_dir/cloudflared"
        asset="cloudflared-linux-${cf_arch}"
        if ! github_release_fetch cloudflare/cloudflared latest "$metadata"; then
            rm -rf -- "$tmp_dir"
            err "获取 cloudflared 版本信息失败."
        fi
        latest=$(github_release_tag "$metadata")
        if ! download_verified_release_asset cloudflare/cloudflared "$latest" "$asset" "$candidate" cloudflared; then
            rm -rf -- "$tmp_dir"
            err "下载或校验 cloudflared 失败."
        fi
        chmod +x "$candidate"
        if ! "$candidate" --version > /dev/null 2>&1; then
            rm -rf -- "$tmp_dir"
            err "cloudflared 候选文件无法运行."
        fi
        install -m 0755 "$candidate" /usr/local/bin/cloudflared
        rm -rf -- "$tmp_dir"
        managed_record file /usr/local/bin/cloudflared
        msg "Cloudflare Tunnel 安装完成: $(_green "$latest")"
    fi
}
