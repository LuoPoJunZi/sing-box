#!/bin/bash

is_log_level_list=(trace debug info warn error fatal panic none del)

log_set() {
    if [[ $1 ]]; then
        for v in "${is_log_level_list[@]}"; do
            [[ $(grep -E -i "^${1,,}$" <<< $v) ]] && is_log_level_use=$v && break
        done
        [[ ! $is_log_level_use ]] && err "无法识别 log 参数."

        case $is_log_level_use in
            del)
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                msg "\n $(_green 已临时删除 log 文件.)\n"
                ;;
            none)
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                json_write_config "$(jq '.log={"disabled":true}' $is_config_json)"
                ;;
            *)
                json_write_config "$(jq '.log={output:"/var/log/'$is_core'/access.log",level:"'$is_log_level_use'","timestamp":true}' $is_config_json)"
                ;;
        esac

        manage restart &
        [[ $1 != 'del' ]] && msg "\n已更新 Log 设定为: $(_green $is_log_level_use)\n"
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
