#!/bin/bash

install_cloudflared() {
    if ! command -v cloudflared > /dev/null 2>&1; then
        msg "正在下载并安装 Cloudflare Tunnel (cloudflared)..."
        local cf_arch="amd64" tmp_dir metadata latest asset candidate candidate_version
        if [[ $(uname -m) =~ "aarch64" || $(uname -m) =~ "armv8" ]]; then
            cf_arch="arm64"
        fi
        tmp_dir=$(mktemp -d 2> /dev/null || mktemp -d -t 'cloudflared-XXXXXX') || {
            err "创建 cloudflared 临时目录失败."
            return 1
        }
        metadata="$tmp_dir/release.json"
        candidate="$tmp_dir/cloudflared"
        asset="cloudflared-linux-${cf_arch}"
        if ! github_release_fetch cloudflare/cloudflared latest "$metadata"; then
            rm -rf -- "$tmp_dir"
            err "获取 cloudflared 版本信息失败."
            return 1
        fi
        latest=$(github_release_tag "$metadata")
        if cloudflared_version_is_blocked "$latest"; then
            rm -rf -- "$tmp_dir"
            err "cloudflared $latest 存在官方确认的路径处理问题，已拒绝安装."
            return 1
        fi
        if ! download_verified_release_asset cloudflare/cloudflared "$latest" "$asset" "$candidate" cloudflared; then
            rm -rf -- "$tmp_dir"
            err "下载或校验 cloudflared 失败."
            return 1
        fi
        chmod +x "$candidate"
        if ! candidate_version=$("$candidate" --version 2> /dev/null); then
            rm -rf -- "$tmp_dir"
            err "cloudflared 候选文件无法运行."
            return 1
        fi
        candidate_version=$(awk 'NR == 1 {print $3}' <<< "$candidate_version")
        candidate_version=${candidate_version%$'\r'}
        if [[ -z $candidate_version || $(version_normalize "$candidate_version") != "${latest#v}" ]] || cloudflared_version_is_blocked "$candidate_version"; then
            rm -rf -- "$tmp_dir"
            err "cloudflared 候选文件无法运行、版本不匹配或存在已知路径问题."
            return 1
        fi
        if ! install -m 0755 "$candidate" /usr/local/bin/cloudflared; then
            rm -rf -- "$tmp_dir"
            err "安装 cloudflared 失败."
            return 1
        fi
        rm -rf -- "$tmp_dir"
        managed_record file /usr/local/bin/cloudflared
        msg "Cloudflare Tunnel 安装完成: $(_green "$latest")"
    fi
}
