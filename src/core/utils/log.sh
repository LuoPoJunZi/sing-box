#!/bin/bash

is_log_level_list=(trace debug info warn error fatal panic none del)

log_set() {
    local candidate=""

    if [[ $1 ]]; then
        is_log_level_use=""
        for v in "${is_log_level_list[@]}"; do
            [[ $(grep -E -i "^${1,,}$" <<< "$v") ]] && is_log_level_use=$v && break
        done
        if [[ ! $is_log_level_use ]]; then
            err "无法识别 log 参数."
            return 1
        fi

        if [[ ${is_dry_run:-} ]]; then
            msg "DRY-RUN: 将更新日志设置 ($is_log_level_use)，本次不写入或删除日志"
            return 0
        fi

        case $is_log_level_use in
            del)
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                msg "\n $(_green 已临时删除 log 文件.)\n"
                return 0
                ;;
            none)
                [[ -f $is_config_json ]] || {
                    err "主配置文件不存在: $is_config_json"
                    return 1
                }
                candidate=$(jq '.log={"disabled":true}' "$is_config_json") || {
                    err "解析或生成日志配置失败: $is_config_json"
                    return 1
                }
                snapshot_ensure "write-log" || return 1
                if declare -F node_commit_config > /dev/null 2>&1; then
                    node_commit_config main "$candidate" || return 1
                else
                    json_write_config "$candidate" || return 1
                fi
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                ;;
            *)
                [[ -f $is_config_json ]] || {
                    err "主配置文件不存在: $is_config_json"
                    return 1
                }
                candidate=$(MSYS2_ARG_CONV_EXCL='*' jq --arg output "/var/log/$is_core/access.log" --arg level "$is_log_level_use" '.log={output:$output,level:$level,timestamp:true}' < "$is_config_json") || {
                    err "解析或生成日志配置失败: $is_config_json"
                    return 1
                }
                snapshot_ensure "write-log" || return 1
                if declare -F node_commit_config > /dev/null 2>&1; then
                    node_commit_config main "$candidate" || return 1
                else
                    json_write_config "$candidate" || return 1
                fi
                ;;
        esac

        manage restart &
        msg "\n已更新 Log 设定为: $(_green "$is_log_level_use")\n"
    else
        if [[ -f $is_log_dir/access.log ]]; then
            msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
            tail -f $is_log_dir/access.log
        else
            err "无法找到 log 文件."
        fi
    fi
}

# ----------------- DNS 模块 -----------------
is_dns_list=(1.1.1.1 8.8.8.8 h3://dns.google/dns-query h3://cloudflare-dns.com/dns-query h3://family.cloudflare-dns.com/dns-query set none)
