#!/bin/bash

query_get() {
    case $1 in
        addr)
            is_addr=$host
            if [[ ! $is_addr ]]; then
                get_ip
                is_addr=$ip
                if [[ $ip == *:* ]]; then is_addr="[$ip]"; fi
            fi
            ;;
        new)
            if [[ ! $host ]]; then get_ip; fi
            if [[ ! $port ]]; then
                get_port
                port=$tmp_port
            fi
            if [[ ! $uuid ]]; then
                get_uuid
                uuid=$tmp_uuid
            fi
            ;;
        file)
            is_file_str=$2
            if [[ ! $is_file_str ]]; then is_file_str='.json$'; fi
            mapfile -t is_all_json < <(list_conf_json_names "$is_file_str")
            if [[ ${#is_all_json[@]} -eq 0 ]]; then err "无法找到相关的配置文件: $2"; fi
            if [[ ${#is_all_json[@]} -eq 1 ]]; then
                is_config_file=${is_all_json[0]}
                is_auto_get_config=1
            fi
            if [[ ! $is_config_file ]]; then
                if [[ $is_dont_auto_exit ]]; then return; fi
                ask get_config_file
            fi
            ;;
        info)
            get file $2
            if [[ $is_config_file ]]; then
                query_read_node "$is_conf_dir/$is_config_file" || {
                    err "无法读取此文件: $is_config_file"
                    return 1
                }
                is_socks_user=$username
                is_socks_pass=$password
                is_config_name=$is_config_file

                if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                    is_tmp_https_port=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
                fi
                if [[ $host && ! -f $is_caddy_conf/$host.conf ]]; then is_no_auto_tls=1; fi
                if [[ $is_tmp_https_port ]]; then is_https_port=$is_tmp_https_port; fi
                if [[ $is_client && $host ]]; then port=$is_https_port; fi
                query_protocol_metadata
            fi
            ;;
        host-test)
            if [[ $is_no_auto_tls || $is_gen || $is_dont_test_host ]]; then return; fi
            get_ip
            get ping
            if [[ ! $(grep $ip <<< $is_host_dns) ]]; then
                msg "\n请将 ($(_red_bg $host)) 解析到 ($(_red_bg $ip))"
                msg "\n如果使用 Cloudflare, 在 DNS 那; 关闭 (Proxy status / 代理状态), 即是 (DNS only / 仅限 DNS)"
                ask string y "我已经确定解析 [y]:"
                get ping
                if [[ ! $(grep $ip <<< $is_host_dns) ]]; then
                    _cyan "\n测试结果: $is_host_dns"
                    err "域名 ($host) 没有解析到 ($ip)"
                fi
            fi
            ;;
        ssss | ss2022)
            if [[ $ss_method == *128* ]]; then
                $is_core_bin generate rand 16 --base64
            else
                $is_core_bin generate rand 32 --base64
            fi
            ;;
        ping)
            is_dns_type="a"
            if [[ $ip == *:* ]]; then is_dns_type="aaaa"; fi
            is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
            ;;
    esac
}
