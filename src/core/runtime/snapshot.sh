#!/bin/bash

runtime_snapshot_dir() {
    echo "$is_sh_dir/backups"
}

runtime_snapshot_normalize_reason() {
    local reason=${1:-manual}

    reason=${reason//$'\r'/-}
    reason=${reason//$'\n'/-}
    reason=${reason//\//-}
    reason=${reason//\\/-}
    reason=${reason//|/-}
    reason=${reason:0:80}
    [[ $reason ]] || reason=manual
    printf '%s\n' "$reason"
}

runtime_snapshot_list_ids() {
    local backup_root=${1:-$(runtime_snapshot_dir)}

    [[ -d $backup_root ]] || return
    find "$backup_root" -mindepth 1 -maxdepth 1 -type d -printf '%T@|%f\n' 2> /dev/null |
        sort -t '|' -k 1,1nr |
        cut -d '|' -f 2-
}

runtime_snapshot_ensure() {
    local reason i
    local backup_root snapshot_id snapshot_dir
    local snapshot_items=()

    reason=$(runtime_snapshot_normalize_reason "${1:-manual}")

    if [[ $is_gen || $is_test_json || $is_disable_snapshot ]]; then
        return
    fi
    if [[ $is_snapshot_id ]]; then
        return
    fi

    if [[ $is_dry_run ]]; then
        is_snapshot_id="dryrun-$(date +%Y%m%d-%H%M%S)-${reason}"
        msg "DRY-RUN: 将创建配置快照: $(_green $is_snapshot_id)"
        return
    fi

    backup_root="$(runtime_snapshot_dir)"
    mkdir -p "$backup_root"

    snapshot_id="$(date +%Y%m%d-%H%M%S)-${reason}"
    snapshot_dir="$backup_root/$snapshot_id"
    mkdir -p "$snapshot_dir"

    if [[ -f $is_config_json ]]; then
        cp -f -- "$is_config_json" "$snapshot_dir/config.json"
    fi
    if [[ -d $is_conf_dir && $is_conf_dir != '/' ]]; then
        mkdir -p "$snapshot_dir/conf"
        cp -rf -- "$is_conf_dir/." "$snapshot_dir/conf/"
    elif [[ -d $is_conf_dir ]]; then
        warn "跳过不安全的节点目录快照: $is_conf_dir"
    fi
    if [[ $is_caddy && -d $is_caddy_conf && $is_caddy_dir && $is_caddy_conf == "$is_caddy_dir/"* && $is_caddy_conf != "$is_caddy_dir/" ]]; then
        mkdir -p "$snapshot_dir/caddy-conf"
        cp -rf -- "$is_caddy_conf/." "$snapshot_dir/caddy-conf/"
    elif [[ $is_caddy && -d $is_caddy_conf ]]; then
        warn "跳过不安全的 Caddy 目录快照: $is_caddy_conf"
    fi

    cat > "$snapshot_dir/meta.txt" << EOF
created_at=$(date '+%F %T %z')
reason=$reason
core_version=$is_core_ver
script_version=$is_sh_ver
EOF

    # 保留最近 20 个快照，避免长期占用磁盘。
    mapfile -t snapshot_items < <(runtime_snapshot_list_ids "$backup_root")
    for ((i = 20; i < ${#snapshot_items[@]}; i++)); do
        rm -rf -- "${backup_root:?}/${snapshot_items[$i]}"
    done

    is_snapshot_id="$snapshot_id"
    msg "已创建配置快照: $(_green $snapshot_id)"
}

runtime_snapshot_list() {
    local backup_root snapshot_id
    local snapshot_items=()
    backup_root="$(runtime_snapshot_dir)"

    if [[ ! -d $backup_root ]]; then
        msg "\n未找到任何快照目录.\n"
        return
    fi

    msg "\n------------- 配置快照列表 -------------"
    mapfile -t snapshot_items < <(runtime_snapshot_list_ids "$backup_root")
    for snapshot_id in "${snapshot_items[@]}"; do
        msg "$snapshot_id"
    done
    msg "----------------------------------------\n"
}
