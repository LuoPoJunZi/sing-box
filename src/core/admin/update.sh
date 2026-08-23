#!/bin/bash

admin_update_abort() {
    local reason=$1

    download_stage_cleanup
    err "$reason"
    return 1
}

admin_update_service_healthy() {
    local service_name=$1 binary=$2

    sleep 3
    systemctl is-active --quiet "$service_name" && pgrep -f "$binary" > /dev/null 2>&1
}

admin_update_replace_binary() {
    local candidate=$1 target=$2

    install -m 0755 "$candidate" "${target}.new" && mv -f -- "${target}.new" "$target"
}

admin_update_core_preflight() {
    local target_version=$1 config_file
    local manual_files=()

    version_is_at_least "$target_version" 1.14.0 || return 0
    if ! command -v jq > /dev/null 2>&1; then
        msg "缺少 jq，无法执行 sing-box 1.14 配置兼容预检."
        return 1
    fi
    mapfile -t manual_files < <(compat_sing_box_114_manual_files "$is_config_json" "$is_conf_dir")
    [[ ${#manual_files[@]} -eq 0 ]] && return 0

    msg "检测到 sing-box 1.14 无法安全自动迁移的配置:"
    for config_file in "${manual_files[@]}"; do
        msg "  - $config_file"
    done
    msg "请先执行 sb doctor，并按提示手动迁移后再更新核心."
    return 1
}

admin_update_cloudflared_version_allowed() {
    local version=$1

    if cloudflared_version_is_blocked "$version"; then
        msg "cloudflared $version 存在官方确认的 HTTP 路径处理问题，已拒绝安装."
        msg "请使用 cloudflared 2026.8.2 或更高版本."
        return 1
    fi
}

admin_update_core() {
    local candidate="$download_stage_root/$is_core"
    local candidate_config=$is_config_json old_binary="$download_stage_dir/core.old"
    local old_config="$download_stage_dir/config.old" migrated_config="$download_stage_dir/config.migrated.json"
    local migrated_dns=0

    if ! "$candidate" version > /dev/null 2>&1; then
        admin_update_abort "$is_core_name 候选核心无法运行."
        return 1
    fi

    if [[ -f $is_config_json ]] && dns_config_uses_legacy_servers "$is_config_json"; then
        if ! dns_build_modern_config "$is_config_json" "$migrated_config"; then
            admin_update_abort "旧版 DNS 配置无法自动迁移，请先执行 sb dns 重新选择 DNS."
            return 1
        fi
        candidate_config=$migrated_config
        migrated_dns=1
        msg "检测到旧版 DNS address 格式，候选配置已转换为 type/server 格式."
    fi

    if [[ -f $candidate_config ]] && ! json_check_core_config_with "$candidate" "$candidate_config"; then
        admin_update_abort "候选核心未通过现有配置校验，未替换当前核心."
        return 1
    fi

    cp -p -- "$is_core_bin" "$old_binary" || {
        admin_update_abort "无法备份当前核心."
        return 1
    }
    if [[ -f $is_config_json ]]; then
        cp -p -- "$is_config_json" "$old_config" || {
            admin_update_abort "无法备份当前配置."
            return 1
        }
    fi

    unset is_snapshot_id
    runtime_snapshot_ensure "pre-core-update-$is_new_ver"
    if [[ $migrated_dns -eq 1 ]]; then
        if ! cp -f -- "$candidate_config" "${is_config_json}.new" || ! mv -f -- "${is_config_json}.new" "$is_config_json"; then
            admin_update_abort "写入新版 DNS 配置失败."
            return 1
        fi
    fi

    if ! admin_update_replace_binary "$candidate" "$is_core_bin" || ! systemctl restart "$is_core"; then
        cp -p -- "$old_binary" "$is_core_bin"
        [[ -f $old_config ]] && cp -p -- "$old_config" "$is_config_json"
        systemctl restart "$is_core" > /dev/null 2>&1 || true
        admin_update_abort "$is_core_name 更新失败，已恢复旧核心和配置."
        return 1
    fi

    if ! admin_update_service_healthy "$is_core" "$is_core_bin"; then
        cp -p -- "$old_binary" "$is_core_bin"
        [[ -f $old_config ]] && cp -p -- "$old_config" "$is_config_json"
        systemctl restart "$is_core" > /dev/null 2>&1 || true
        admin_update_abort "$is_core_name 更新后未通过健康检查，已恢复旧核心和配置."
        return 1
    fi
    if [[ $migrated_dns -eq 1 ]]; then
        msg "DNS 配置已安全迁移，并通过新核心校验."
    fi
}

admin_update_caddy() {
    local candidate="$download_stage_root/caddy" old_binary="$download_stage_dir/caddy.old"

    if ! "$candidate" version > /dev/null 2>&1; then
        admin_update_abort "Caddy 候选文件无法运行."
        return 1
    fi
    if [[ -f $is_caddyfile ]] && ! "$candidate" validate --config "$is_caddyfile" --adapter caddyfile > /dev/null 2>&1; then
        admin_update_abort "候选 Caddy 未通过现有 Caddyfile 校验."
        return 1
    fi
    cp -p -- "$is_caddy_bin" "$old_binary" || {
        admin_update_abort "无法备份当前 Caddy."
        return 1
    }
    if ! admin_update_replace_binary "$candidate" "$is_caddy_bin" || ! systemctl restart caddy; then
        cp -p -- "$old_binary" "$is_caddy_bin"
        systemctl restart caddy > /dev/null 2>&1 || true
        admin_update_abort "Caddy 更新失败，已恢复旧版本."
        return 1
    fi
    if ! admin_update_service_healthy caddy "$is_caddy_bin"; then
        cp -p -- "$old_binary" "$is_caddy_bin"
        systemctl restart caddy > /dev/null 2>&1 || true
        admin_update_abort "Caddy 更新后未通过健康检查，已恢复旧版本."
        return 1
    fi
}

admin_update_script_validate() {
    local candidate_root=$1 shell_file

    while IFS= read -r -d '' shell_file; do
        bash -n "$shell_file" || return 1
    done < <(find "$candidate_root" -type f -name '*.sh' -print0)
    (
        cd "$candidate_root" || exit 1
        bash scripts/check-structure.sh
    ) > /dev/null 2>&1
}

admin_update_script() {
    local candidate_root=$download_stage_root
    local backup_dir="${is_sh_dir}.rollback-${is_new_ver#v}-$$" failed_dir="${is_sh_dir}.failed-$$"
    local persistent_item
    local persistent_items=(
        .install_manifest
        backups
        snapshots
        domain_custom.list
        domain_disabled.list
        domain_health.cache
        domain_recent.list
    )

    if ! grep -q "is_sh_ver=\"$is_new_ver\"" "$candidate_root/src/init.sh"; then
        admin_update_abort "脚本发布包版本与目标版本不一致."
        return 1
    fi
    if ! admin_update_script_validate "$candidate_root"; then
        admin_update_abort "脚本候选版本未通过语法或结构检查."
        return 1
    fi

    for persistent_item in "${persistent_items[@]}"; do
        if [[ -e $is_sh_dir/$persistent_item ]]; then
            cp -a -- "$is_sh_dir/$persistent_item" "$candidate_root/"
        fi
    done

    rm -rf -- "$backup_dir" "$failed_dir"
    if ! mv -- "$is_sh_dir" "$backup_dir" || ! mv -- "$candidate_root" "$is_sh_dir"; then
        [[ ! -d $is_sh_dir && -d $backup_dir ]] && mv -- "$backup_dir" "$is_sh_dir"
        admin_update_abort "脚本目录切换失败，已恢复旧版本."
        return 1
    fi
    chmod +x "$is_sh_bin" "${is_sh_bin/$is_core/sb}"

    if ! NO_COLOR=1 TERM=dumb "$is_sh_bin" version > /dev/null 2>&1; then
        mv -- "$is_sh_dir" "$failed_dir"
        mv -- "$backup_dir" "$is_sh_dir"
        rm -rf -- "$failed_dir"
        admin_update_abort "新脚本启动检查失败，已恢复旧版本."
        return 1
    fi
    rm -rf -- "$backup_dir"
}

admin_update_cloudflared() {
    local candidate="$download_stage_root/cloudflared" target=/usr/local/bin/cloudflared
    local old_binary="$download_stage_dir/cloudflared.old" service_name rollback_service candidate_version
    local services=()

    if ! "$candidate" --version > /dev/null 2>&1; then
        admin_update_abort "cloudflared 候选文件无法运行."
        return 1
    fi
    candidate_version=$("$candidate" --version 2> /dev/null | awk 'NR == 1 {print $3}')
    if [[ -z $candidate_version ]]; then
        admin_update_abort "无法识别 cloudflared 候选版本."
        return 1
    fi
    if ! admin_update_cloudflared_version_allowed "$candidate_version"; then
        admin_update_abort "cloudflared 候选版本已被安全规则阻止."
        return 1
    fi
    if [[ $(version_normalize "$candidate_version") != "$(version_normalize "$is_new_ver")" ]]; then
        admin_update_abort "cloudflared 候选版本与目标版本不一致."
        return 1
    fi
    cp -p -- "$target" "$old_binary" || {
        admin_update_abort "无法备份当前 cloudflared."
        return 1
    }
    admin_update_replace_binary "$candidate" "$target" || {
        admin_update_abort "cloudflared 文件替换失败."
        return 1
    }

    mapfile -t services < <(systemctl list-units --type=service --state=running --no-legend 'cftunnel-*.service' 2> /dev/null | awk '{print $1}')
    for service_name in "${services[@]}"; do
        if ! systemctl restart "$service_name" || ! admin_update_service_healthy "$service_name" "$target"; then
            cp -p -- "$old_binary" "$target"
            for rollback_service in "${services[@]}"; do
                systemctl restart "$rollback_service" > /dev/null 2>&1 || true
            done
            admin_update_abort "cloudflared 更新后隧道服务异常，已恢复旧版本."
            return 1
        fi
    done
    managed_record file "$target"
}

admin_update() {
    case $1 in
        1 | core | "$is_core")
            is_update_name=core
            is_show_name="$is_core_name"
            is_run_ver=v${is_core_ver##* }
            ;;
        2 | sh)
            is_update_name="sh"
            is_show_name="$is_core_name 脚本"
            is_run_ver="$is_sh_ver"
            ;;
        3 | caddy)
            if [[ ! $is_caddy ]]; then err "不支持更新 Caddy."; fi
            is_update_name=caddy
            is_show_name="Caddy"
            is_run_ver="$is_caddy_ver"
            ;;
        4 | cloudflared)
            if ! command -v cloudflared > /dev/null 2>&1; then err "尚未安装 cloudflared."; fi
            is_update_name=cloudflared
            is_show_name=cloudflared
            is_run_ver=$(cloudflared --version 2> /dev/null | awk 'NR == 1 {print $3}')
            ;;
        *)
            err "无法识别 ($1), 请使用: $is_core update [core | sh | caddy | cloudflared] [ver]"
            ;;
    esac

    if [[ $2 ]]; then
        if [[ $is_update_name == cloudflared ]]; then
            is_new_ver=${2#v}
        else
            is_new_ver=v${2#v}
        fi
    fi

    if [[ $is_run_ver == "$is_new_ver" ]]; then
        msg "\n自定义版本和当前 $is_show_name 版本一样, 无需更新.\n"
        exit
    fi

    if [[ $is_new_ver ]]; then
        msg "\n使用自定义版本更新 $is_show_name: $(_green $is_new_ver)\n"
    else
        get_latest_version "$is_update_name"
        if [[ $is_run_ver == "$latest_ver" ]]; then
            msg "\n$is_show_name 当前已经是最新版本了.\n"
            exit
        fi
        msg "\n发现 $is_show_name 新版本: $(_green $latest_ver)\n"
        is_new_ver=$latest_ver
    fi

    case $is_update_name in
        core)
            admin_update_core_preflight "$is_new_ver" || err "sing-box 核心更新预检未通过."
            ;;
        cloudflared)
            admin_update_cloudflared_version_allowed "$is_new_ver" || err "cloudflared 更新预检未通过."
            ;;
    esac

    download_stage_component "$is_update_name" "$is_new_ver"
    case $is_update_name in
        core) admin_update_core || return 1 ;;
        sh) admin_update_script || return 1 ;;
        caddy) admin_update_caddy || return 1 ;;
        cloudflared) admin_update_cloudflared || return 1 ;;
    esac
    download_stage_cleanup
    msg "更新成功, 当前 $is_show_name 版本: $(_green $is_new_ver)\n"
}
