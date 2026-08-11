#!/bin/bash

get_latest_version() {
    local metadata repo tmpdir

    case $1 in
        core)
            name=$is_core_name
            repo=$is_core_repo
            ;;
        sh)
            name="$is_core_name 脚本"
            repo=$is_sh_repo
            ;;
        caddy)
            name="Caddy"
            repo=$is_caddy_repo
            ;;
        cloudflared)
            name=cloudflared
            repo=cloudflare/cloudflared
            ;;
        *) err "无法识别下载组件: $1" ;;
    esac
    tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'release-XXXXXX')
    metadata="$tmpdir/release.json"
    if github_release_fetch "$repo" latest "$metadata"; then
        latest_ver=$(github_release_tag "$metadata")
    fi
    rm -rf -- "$tmpdir"
    [[ ! $latest_ver ]] && err "获取 ${name} 最新版本失败."
    unset name repo metadata
}

download_tar_paths_safe() {
    local archive=$1 entry normalized

    tar tzf "$archive" > /dev/null 2>&1 || return 1
    while IFS= read -r entry; do
        normalized=${entry#./}
        if [[ ! $normalized || $normalized == '.' ]]; then
            continue
        fi
        if [[ $normalized == /* || $normalized == '..' || $normalized == ../* || $normalized == */../* ]]; then
            return 1
        fi
    done < <(tar tzf "$archive")
}

download_stage_cleanup() {
    if [[ ${download_stage_dir:-} && -d $download_stage_dir ]]; then
        rm -rf -- "$download_stage_dir"
    fi
    unset download_stage_dir download_stage_root
}

download_stage_component() {
    local component=$1 version=${2:-} stage_parent=${3:-$is_core_dir}
    local repo="" asset="" archive="" name=""

    download_stage_cleanup
    if [[ ! $version ]]; then
        get_latest_version "$component"
        version=$latest_ver
    fi
    github_release_tag_is_safe "$version" || err "Release 版本号包含不安全字符: $version"

    case $component in
        core)
            name=$is_core_name
            repo=$is_core_repo
            asset="${is_core}-${version#v}-linux-${is_arch}.tar.gz"
            ;;
        sh)
            name="$is_core_name 脚本"
            repo=$is_sh_repo
            asset=code.tar.gz
            ;;
        caddy)
            name=Caddy
            repo=$is_caddy_repo
            asset="caddy_${version#v}_linux_${is_arch}.tar.gz"
            ;;
        cloudflared)
            name=cloudflared
            repo=cloudflare/cloudflared
            asset="cloudflared-linux-${is_arch}"
            ;;
        *) err "无法识别下载组件: $component" ;;
    esac

    mkdir -p "$stage_parent"
    download_stage_dir=$(mktemp -d "$stage_parent/.sb-update.XXXXXX" 2> /dev/null || mktemp -d -t 'sb-update-XXXXXX')
    download_stage_root="$download_stage_dir/content"
    archive="$download_stage_dir/$asset"
    mkdir -p "$download_stage_root"

    msg "正在下载并校验 $name: $(_green "$version")"
    if ! download_verified_release_asset "$repo" "$version" "$asset" "$archive" "$name"; then
        download_stage_cleanup
        err "下载或校验 $name 失败."
    fi
    downloaded_version=$download_release_tag

    case $component in
        core)
            if ! download_tar_paths_safe "$archive" || ! tar zxf "$archive" --strip-components 1 -C "$download_stage_root"; then
                download_stage_cleanup
                err "$name 发布包无法解压."
            fi
            [[ -f $download_stage_root/$is_core ]] || {
                download_stage_cleanup
                err "$name 发布包中缺少核心文件."
            }
            chmod +x "$download_stage_root/$is_core"
            ;;
        sh)
            if ! download_tar_paths_safe "$archive" || ! tar zxf "$archive" -C "$download_stage_root"; then
                download_stage_cleanup
                err "$name 发布包无法解压."
            fi
            [[ -f $download_stage_root/sing-box.sh && -f $download_stage_root/src/init.sh ]] || {
                download_stage_cleanup
                err "$name 发布包结构无效."
            }
            ;;
        caddy)
            if ! download_tar_paths_safe "$archive" || ! tar zxf "$archive" -C "$download_stage_root"; then
                download_stage_cleanup
                err "$name 发布包无法解压."
            fi
            [[ -f $download_stage_root/caddy ]] || {
                download_stage_cleanup
                err "$name 发布包中缺少可执行文件."
            }
            chmod +x "$download_stage_root/caddy"
            ;;
        cloudflared)
            cp -f -- "$archive" "$download_stage_root/cloudflared"
            chmod +x "$download_stage_root/cloudflared"
            ;;
    esac
}

download() {
    latest_ver=$2
    [[ ! $latest_ver ]] && get_latest_version "$1"
    github_release_tag_is_safe "$latest_ver" || err "Release 版本号包含不安全字符: $latest_ver"
    tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'tmp-XXXXXX')

    case $1 in
        core)
            name=$is_core_name
            tmpfile=$tmpdir/$is_core.tar.gz
            repo=$is_core_repo
            asset="${is_core}-${latest_ver#v}-linux-${is_arch}.tar.gz"
            download_file
            download_tar_paths_safe "$tmpfile" || err "$name 发布包包含不安全路径."
            tar zxf "$tmpfile" --strip-components 1 -C "$is_core_dir/bin" || err "$name 发布包解压失败."
            chmod +x "$is_core_bin"
            ;;
        sh)
            name="$is_core_name 脚本"
            tmpfile=$tmpdir/sh.tar.gz
            repo=$is_sh_repo
            asset=code.tar.gz
            download_file
            download_tar_paths_safe "$tmpfile" || err "$name 发布包包含不安全路径."
            tar zxf "$tmpfile" -C "$is_sh_dir" || err "$name 发布包解压失败."
            chmod +x "$is_sh_bin" "${is_sh_bin/$is_core/sb}"
            ;;
        caddy)
            name="Caddy"
            tmpfile=$tmpdir/caddy.tar.gz
            repo=$is_caddy_repo
            asset="caddy_${latest_ver#v}_linux_${is_arch}.tar.gz"
            download_file
            download_tar_paths_safe "$tmpfile" || err "$name 发布包包含不安全路径."
            tar zxf "$tmpfile" -C "$tmpdir" || err "$name 发布包解压失败."
            cp -f "$tmpdir/caddy" "$is_caddy_bin"
            chmod +x "$is_caddy_bin"
            managed_record file "$is_caddy_bin"
            managed_record dir "$is_caddy_dir"
            managed_record file /lib/systemd/system/caddy.service
            ;;
    esac
    rm -rf -- "$tmpdir"
    unset latest_ver
}

download_file() {
    if ! download_verified_release_asset "$repo" "$latest_ver" "$asset" "$tmpfile" "$name"; then
        rm -rf -- "$tmpdir"
        err "\n下载 ${name} 失败.\n"
    fi
}

# ----------------- BBR 模块 -----------------
