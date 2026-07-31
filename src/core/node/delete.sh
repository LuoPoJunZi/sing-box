#!/bin/bash

write_del() {
    is_dont_get_ip=1
    if [[ $is_conf_dir_empty ]]; then
        return
    fi
    if [[ ! $is_config_file ]]; then
        get info $1
    fi
    if [[ $is_config_file ]]; then
        snapshot_ensure "write-del"
        if [[ $is_dry_run ]]; then
            msg "DRY-RUN: 将删除配置文件 -> $is_conf_dir/$is_config_file"
            return
        fi
        if [[ $is_main_start && ! $is_no_del_msg ]]; then
            msg "\n$(ui_danger_text "即将删除配置文件"): $is_config_file"
            pause
        fi
        rm -f -- "${is_conf_dir:?}/$is_config_file"

        if [[ $is_config_file =~ "CFtunnel" ]]; then
            if [[ $port ]]; then
                systemctl disable --now cftunnel-${port}.service &> /dev/null
                rm -f /lib/systemd/system/cftunnel-${port}.service
                systemctl daemon-reload
                msg "✅ 已清理对应的 CFtunnel 穿透守护服务 (端口: $port)."
            fi
        fi

        if [[ ! $is_new_json ]]; then
            manage restart &
        fi
        if [[ ! $is_no_del_msg ]]; then
            ui_success_msg "已删除: $is_config_file"
            msg
        fi

        if [[ $is_caddy ]]; then
            is_del_host=$host
            if [[ $is_change ]]; then
                if [[ ! $old_host ]]; then
                    return
                fi
                is_del_host=$old_host
            fi
            if [[ $is_del_host && $host != "$old_host" && -f $is_caddy_conf/$is_del_host.conf ]]; then
                rm -rf -- "$is_caddy_conf/$is_del_host.conf" "$is_caddy_conf/$is_del_host.conf.add"
                if [[ ! $is_new_json ]]; then
                    manage restart caddy &
                fi
            fi
        fi
    fi
    local conf_files=()
    mapfile -t conf_files < <(list_conf_json_names '.json$')
    if [[ ${#conf_files[@]} -eq 0 && ! $is_change ]]; then
        warn "当前配置目录为空! 因为你刚刚删除了最后一个配置文件."
        is_conf_dir_empty=1
    fi
    unset is_dont_get_ip
    if [[ $is_dont_auto_exit ]]; then
        unset is_config_file
    fi
}
