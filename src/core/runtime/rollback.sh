#!/bin/bash

runtime_snapshot_restore() {
    local backup_root target_id target_dir
    local snapshot_items=()
    backup_root="$(runtime_snapshot_dir)"
    target_id="$1"

    if [[ ! -d $backup_root ]]; then
        err "未找到快照目录."
        return 1
    fi

    if [[ ! $target_id ]]; then
        mapfile -t snapshot_items < <(runtime_snapshot_list_ids "$backup_root")
        if [[ ${#snapshot_items[@]} -eq 0 ]]; then
            err "没有可回滚的快照."
            return 1
        fi

        if [[ $is_dont_auto_exit ]]; then
            target_id="${snapshot_items[0]}"
        else
            is_tmp_list=("${snapshot_items[@]}")
            ask list target_id "" "\n请选择要回滚的快照:"
            unset is_tmp_list
        fi
    fi

    if [[ $target_id == */* || $target_id == *\\* || $target_id == '.' || $target_id == '..' ]]; then
        err "快照 ID 无效: $target_id"
        return 1
    fi

    target_dir="$backup_root/$target_id"
    if [[ ! -d $target_dir ]]; then
        err "快照不存在: $target_id"
        return 1
    fi

    if [[ -d $target_dir/conf && (! $is_conf_dir || $is_conf_dir == '/') ]]; then
        err "拒绝清理不安全的节点目录: $is_conf_dir"
        return 1
    fi
    if [[ $is_caddy && -d $target_dir/caddy-conf && (! $is_caddy_dir || $is_caddy_conf != "$is_caddy_dir/"* || $is_caddy_conf == "$is_caddy_dir/") ]]; then
        err "拒绝清理不安全的 Caddy 目录: $is_caddy_conf"
        return 1
    fi

    if [[ $is_dry_run ]]; then
        msg "\nDRY-RUN: 将执行回滚 -> $(_green $target_id)"
        msg "DRY-RUN: 将恢复主配置: $is_config_json"
        msg "DRY-RUN: 将恢复节点目录: $is_conf_dir"
        if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
            msg "DRY-RUN: 将恢复 Caddy 目录: $is_caddy_conf"
        fi
        msg "DRY-RUN: 将重启服务: $is_core $([[ $is_caddy ]] && echo '和 caddy')\n"
        return
    fi

    # 回滚前再做一次保护性快照
    unset is_snapshot_id
    runtime_snapshot_ensure "pre-rollback"

    if [[ -f $target_dir/config.json ]]; then
        cp -f -- "$target_dir/config.json" "$is_config_json"
    fi

    if [[ -d $target_dir/conf ]]; then
        rm -rf -- "$is_conf_dir"
        mkdir -p "$is_conf_dir"
        cp -rf -- "$target_dir/conf/." "$is_conf_dir/"
    fi

    if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
        mkdir -p "$is_caddy_conf"
        rm -rf -- "${is_caddy_conf:?}/"*
        cp -rf -- "$target_dir/caddy-conf/." "$is_caddy_conf/"
    fi

    manage restart &
    if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
        manage restart caddy &
    fi

    _green "\n回滚完成: $target_id\n"
}
