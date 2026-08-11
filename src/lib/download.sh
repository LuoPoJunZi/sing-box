#!/bin/bash

download_sha256_file() {
    local file=$1

    command -v sha256sum > /dev/null 2>&1 || return 1
    sha256sum "$file" | awk '{print tolower($1)}'
}

download_verify_sha256() {
    local file=$1 expected=${2#sha256:} actual=""

    [[ $expected =~ ^[0-9a-fA-F]{64}$ ]] || return 1
    actual=$(download_sha256_file "$file") || return 1
    [[ $actual == "${expected,,}" ]]
}

download_verified_url() {
    local url=$1 expected=$2 destination=$3 label=${4:-文件}
    local partial="${destination}.part"

    [[ $url == https://* ]] || {
        warn "$label 下载地址不是 HTTPS: $url"
        return 1
    }
    rm -f -- "$partial"
    if ! _wget -q -t 5 -T 60 "$url" -O "$partial"; then
        rm -f -- "$partial"
        warn "下载 $label 失败."
        return 1
    fi
    if ! download_verify_sha256 "$partial" "$expected"; then
        rm -f -- "$partial"
        warn "$label 的 SHA-256 校验失败，已拒绝使用该文件."
        return 1
    fi
    mv -f -- "$partial" "$destination"
}

github_release_api_url() {
    local repo=$1 tag=${2:-latest}

    if [[ $tag == latest ]]; then
        printf 'https://api.github.com/repos/%s/releases/latest\n' "$repo"
    elif github_release_tag_is_safe "$tag"; then
        printf 'https://api.github.com/repos/%s/releases/tags/%s\n' "$repo" "$tag"
    else
        return 1
    fi
}

github_release_tag_is_safe() {
    local tag=$1

    [[ $tag =~ ^v?[0-9A-Za-z][0-9A-Za-z._-]*$ ]]
}

github_release_fetch() {
    local repo=$1 tag=${2:-latest} output=$3
    local url partial="${output}.part"

    command -v jq > /dev/null 2>&1 || {
        warn "缺少 jq，无法读取 GitHub Release 元数据."
        return 1
    }
    if ! url=$(github_release_api_url "$repo" "$tag"); then
        warn "Release 版本号包含不安全字符: $tag"
        return 1
    fi
    rm -f -- "$partial"
    if ! _wget -q -t 5 -T 30 "$url" -O "$partial"; then
        rm -f -- "$partial"
        warn "获取 $repo Release 元数据失败."
        return 1
    fi
    if ! jq -e '.tag_name and (.assets | type == "array")' "$partial" > /dev/null 2>&1; then
        rm -f -- "$partial"
        warn "$repo Release 元数据格式无效."
        return 1
    fi
    mv -f -- "$partial" "$output"
}

github_release_tag() {
    jq -r '.tag_name // empty' "$1"
}

github_release_asset_fields() {
    local metadata=$1 asset_name=$2

    jq -r --arg name "$asset_name" '
        first(.assets[] | select(.name == $name)) |
        select(.browser_download_url != null) |
        [.browser_download_url, (.digest // "")] | @tsv
    ' "$metadata"
}

download_verified_release_asset() {
    local repo=$1 tag=${2:-latest} asset_name=$3 destination=$4 label=""
    local metadata fields url digest work_dir

    label=${5:-$asset_name}

    work_dir=$(dirname "$destination")
    metadata="$work_dir/.release-${RANDOM}.json"
    if ! github_release_fetch "$repo" "$tag" "$metadata"; then
        rm -f -- "$metadata"
        return 1
    fi

    download_release_tag=$(github_release_tag "$metadata")
    fields=$(github_release_asset_fields "$metadata" "$asset_name")
    rm -f -- "$metadata"
    if [[ ! $fields ]]; then
        warn "$repo $download_release_tag 中未找到资源: $asset_name"
        return 1
    fi

    IFS=$'\t' read -r url digest <<< "$fields"
    if [[ $digest != sha256:* ]]; then
        warn "$asset_name 缺少 GitHub SHA-256 摘要，已拒绝下载."
        return 1
    fi
    download_verified_url "$url" "$digest" "$destination" "$label"
}
