#!/bin/bash

query_get() {
    case $1 in
        addr)
            is_addr=$host
            if [[ ! $is_addr ]]; then
                get_ip
                is_addr=$ip
                if [[ $(grep ":" <<< $ip) ]]; then is_addr="[$ip]"; fi
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
                is_json_str=$(cat $is_conf_dir/"$is_config_file" | sed s#//.*##)
                is_json_data=$(jq '(.inbounds[0]|.type,.listen_port,(.users[0]|.uuid,.password,.username),.method,.password,.override_port,.override_address,(.transport|.type,.path,.headers.host),(.tls|.server_name,.reality.private_key,.reality.short_id[0])),(.outbounds[1].tag)' <<< $is_json_str)
                if [[ $? != 0 ]]; then err "无法读取此文件: $is_config_file"; fi
                is_up_var_set=(null is_protocol port uuid password username ss_method ss_password door_port door_addr net_type path host is_servername is_private_key is_short_id is_public_key)
                if [[ $is_debug ]]; then msg "\n------------- debug: $is_config_file -------------"; fi
                i=0
                local json_items=()
                mapfile -t json_items < <(sed 's/""/null/g;s/"//g' <<< "$is_json_data")
                for v in "${json_items[@]}"; do
                    ((i++))
                    if [[ $is_debug ]]; then msg "$i-${is_up_var_set[$i]}: $v"; fi
                    export "${is_up_var_set[$i]}=${v}"
                done
                for v in "${is_up_var_set[@]}"; do
                    if [[ ${!v} == 'null' ]]; then unset "$v"; fi
                done

                if [[ $is_private_key ]]; then
                    is_reality=1
                    net_type+=reality
                    is_public_key=${is_public_key/public_key_/}
                fi
                is_socks_user=$username
                is_socks_pass=$password
                is_config_name=$is_config_file

                if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                    is_tmp_https_port=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
                fi
                if [[ $host && ! -f $is_caddy_conf/$host.conf ]]; then is_no_auto_tls=1; fi
                if [[ $is_tmp_https_port ]]; then is_https_port=$is_tmp_https_port; fi
                if [[ $is_client && $host ]]; then port=$is_https_port; fi
                get protocol $is_protocol-$net_type
            fi
            ;;
        protocol)
            query_prepare_protocol "$2"
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
            if [[ $(grep 128 <<< $ss_method) ]]; then
                $is_core_bin generate rand 16 --base64
            else
                $is_core_bin generate rand 32 --base64
            fi
            ;;
        ping)
            is_dns_type="a"
            if [[ $(grep ":" <<< $ip) ]]; then is_dns_type="aaaa"; fi
            is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
            ;;
        install-caddy)
            _green "\n安装 Caddy 实现自动配置 TLS.\n"
            download caddy
            install_service caddy &> /dev/null
            is_caddy=1
            _green "安装 Caddy 成功.\n"
            ;;
        reinstall)
            is_install_sh=$(cat $is_sh_dir/install.sh)
            uninstall
            bash <<< $is_install_sh
            ;;
        test-run)
            systemctl list-units --full -all &> /dev/null
            if [[ $? != 0 ]]; then
                _yellow "\n无法执行测试, 请检查 systemctl 状态.\n"
                return
            fi
            is_no_manage_msg=1
            if [[ ! $(pgrep -f $is_core_bin) ]]; then
                _yellow "\n测试运行 $is_core_name ..\n"
                manage start &> /dev/null
                if [[ $is_run_fail == "$is_core" ]]; then
                    _red "$is_core_name 运行失败信息:"
                    $is_core_bin run -c $is_config_json -C $is_conf_dir
                else
                    _green "\n测试通过, 已启动 $is_core_name ..\n"
                fi
            else
                _green "\n$is_core_name 正在运行, 跳过测试\n"
            fi
            if [[ $is_caddy ]]; then
                if [[ ! $(pgrep -f $is_caddy_bin) ]]; then
                    _yellow "\n测试运行 Caddy ..\n"
                    manage start caddy &> /dev/null
                    if [[ $is_run_fail == 'caddy' ]]; then
                        _red "Caddy 运行失败信息:"
                        $is_caddy_bin run --config $is_caddyfile
                    else
                        _green "\n测试通过, 已启动 Caddy ..\n"
                    fi
                else
                    _green "\nCaddy 正在运行, 跳过测试\n"
                fi
            fi
            ;;
    esac
}
