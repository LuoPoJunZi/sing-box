#!/bin/bash

query_info() {
    local encoded_remark="" encoded_user="" server_address="" tls_server_name="" uri_query=""

    if [[ ! $is_protocol ]]; then get info $1; fi
    is_value_style=$blue
    is_insecure=
    is_type=
    is_tls_pin_profile=
    is_tls_pin_server_name=
    is_url_error=
    query_tls_pin_reset

    if [[ -z "$custom_remark" ]]; then
        local tmp_name="${is_config_name%.json}"
        local stripped_port="${tmp_name%-[0-9]*}"
        custom_remark="${stripped_port#*-}"
        if [[ -z "$custom_remark" || "$custom_remark" == "$is_protocol" ]]; then
            custom_remark="luopojunzi"
        fi
    fi
    encoded_remark=$(query_uri_encode "$custom_remark")
    server_address=$(query_uri_host_name "$is_addr")
    tls_server_name=$server_address

    if [[ $is_config_name =~ "CFtunnel" ]]; then
        is_value_style=$magenta
        is_can_change=(0 2 5)
        is_info_show=(0 1 2 3 4 6 7 8)
        is_info_str=(vless "$host" "443" $uuid ws "$host" "$path" tls)
        query_uri_params_reset
        query_uri_param encryption none
        query_uri_param security tls
        query_uri_param type ws
        query_uri_param sni "$host"
        query_uri_param host "$host"
        query_uri_param path "$path"
        uri_query=$(query_uri_query)
        is_url="vless://$(query_uri_encode "$uuid")@$host:443${uri_query}#$encoded_remark"
        net="cftunnel_handled"
    fi

    if [[ $is_config_name =~ "AnyTLS" ]]; then net="reality"; fi

    case $net in
        ws | tcp | h2 | quic | http*)
            if [[ $host ]]; then
                is_value_style=$magenta
                is_can_change=(0 1 2 3 5)
                is_info_show=(0 1 2 3 4 6 7 8)
                if [[ $is_protocol == 'vmess' ]]; then
                    is_vmess_url=$(jq -cn --arg ps "$custom_remark" --arg add "$server_address" --arg port "$is_https_port" --arg id "$uuid" --arg net "$net" --arg host "$host" --arg path "$path" '{v:2,ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:$net,type:"none",host:$host,path:$path,tls:"tls",sni:$host}')
                    is_url="vmess://$(printf '%s' "$is_vmess_url" | base64 -w 0)"
                else
                    if [[ $is_protocol == "trojan" ]]; then
                        uuid=$password
                        is_can_change=(0 1 2 3 4)
                        is_info_show=(0 1 2 10 4 6 7 8)
                    fi
                    query_uri_params_reset
                    if [[ $is_protocol == "vless" ]]; then query_uri_param encryption none; fi
                    query_uri_param security tls
                    query_uri_param type "$net"
                    query_uri_param sni "$host"
                    query_uri_param host "$host"
                    query_uri_param path "$path"
                    uri_query=$(query_uri_query)
                    is_url="$is_protocol://$(query_uri_encode "$uuid")@$is_addr:$is_https_port${uri_query}#$encoded_remark"
                fi
                if [[ $is_caddy ]]; then is_can_change+=(11); fi
                is_info_str=($is_protocol $is_addr $is_https_port $uuid $net $host $path 'tls')
            else
                is_type=none
                is_can_change=(0 1 5)
                is_info_show=(0 1 2 3 4)
                is_info_str=($is_protocol $is_addr $port $uuid $net)
                if [[ $net == "http" ]]; then
                    net=tcp
                    is_type=http
                    is_tcp_http=1
                    is_info_show+=(5)
                    is_info_str=(${is_info_str[@]/http/tcp http})
                fi
                if [[ $net == "quic" ]]; then
                    is_tls_pin_profile=vmess-quic
                    is_tls_pin_server_name=$tls_server_name
                    is_info_show+=(8 9 20)
                    is_info_str+=(tls h3 false)
                    query_tls_pin_prepare
                fi
                if [[ $net == "quic" ]]; then
                    is_vmess_url=$(jq -cn --arg ps "$custom_remark" --arg add "$server_address" --arg port "$port" --arg id "$uuid" --arg net "$net" --arg type "$is_type" --arg sni "$tls_server_name" --arg pcs "$tls_pin_cert_sha256_hex" '{v:2,ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:$net,type:$type,tls:"tls",sni:$sni,alpn:"h3",pcs:$pcs}')
                else
                    is_vmess_url=$(jq -cn --arg ps "$custom_remark" --arg add "$server_address" --arg port "$port" --arg id "$uuid" --arg net "$net" --arg type "$is_type" '{v:2,ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:$net,type:$type}')
                fi
                is_url="vmess://$(printf '%s' "$is_vmess_url" | base64 -w 0)"
            fi
            ;;
        ss)
            is_can_change=(0 1 4 6)
            is_info_show=(0 1 2 10 11)
            encoded_user=$(query_uri_base64url "${ss_method}:${ss_password}")
            is_url="ss://${encoded_user}@${is_addr}:${port}#$encoded_remark"
            is_info_str=($is_protocol $is_addr $port $ss_password $ss_method)
            ;;
        trojan)
            is_tls_pin_profile=trojan-self-signed
            is_tls_pin_server_name=$tls_server_name
            is_can_change=(0 1 4)
            is_info_show=(0 1 2 10 4 8 20)
            query_tls_pin_prepare
            query_uri_params_reset
            query_uri_param type tcp
            query_uri_param security tls
            query_uri_param sni "$tls_server_name"
            query_uri_param pcs "$tls_pin_cert_sha256_hex"
            uri_query=$(query_uri_query)
            is_url="$is_protocol://$(query_uri_encode "$password")@$is_addr:$port${uri_query}#$encoded_remark"
            is_info_str=($is_protocol $is_addr $port $password tcp tls false)
            ;;
        hy*)
            is_tls_pin_profile=hysteria2
            is_tls_pin_server_name=$tls_server_name
            is_can_change=(0 1 4)
            is_info_show=(0 1 2 10 8 9 20)
            query_tls_pin_prepare
            query_uri_params_reset
            query_uri_param sni "$tls_server_name"
            query_uri_param alpn h3
            query_uri_param insecure 1
            query_uri_param pinSHA256 "$tls_pin_cert_sha256_hex"
            uri_query=$(query_uri_query)
            is_url="$is_protocol://$(query_uri_encode "$password")@$is_addr:$port/${uri_query}#$encoded_remark"
            is_info_str=($is_protocol $is_addr $port $password tls h3 true)
            ;;
        tuic)
            is_insecure=1
            is_tls_pin_profile=tuic
            is_tls_pin_server_name=$tls_server_name
            is_can_change=(0 1 4 5)
            is_info_show=(0 1 2 3 10 8 9 20 21)
            query_tls_pin_prepare
            query_uri_params_reset
            query_uri_param sni "$tls_server_name"
            query_uri_param alpn h3
            query_uri_param insecure 1
            query_uri_param pcs "$tls_pin_cert_sha256_hex"
            query_uri_param congestion_control bbr
            uri_query=$(query_uri_query)
            encoded_user=$(query_uri_encode "$uuid:$password")
            is_url="$is_protocol://${encoded_user}@$is_addr:$port${uri_query}#$encoded_remark"
            is_info_str=($is_protocol $is_addr $port $uuid $password tls h3 true bbr)
            ;;
        reality)
            is_value_style=$magenta
            is_can_change=(0 1 5 9 10)
            is_info_show=(0 1 2 3 15 4 8 16 17 18)
            is_flow=xtls-rprx-vision
            is_net_type=tcp
            if [[ $net_type =~ "http" || ${is_new_protocol,,} =~ "http" ]]; then
                is_flow=
                is_net_type=h2
                is_info_show=(${is_info_show[@]/15/})
            fi
            is_info_str=($is_protocol $is_addr $port $uuid $is_flow $is_net_type reality $is_servername chrome $is_public_key)
            if [[ $is_short_id ]]; then
                is_info_show+=(22)
                is_info_str+=("$is_short_id")
            fi
            query_uri_params_reset
            query_uri_param encryption none
            query_uri_param security reality
            query_uri_param flow "$is_flow"
            query_uri_param type "$is_net_type"
            query_uri_param sni "$is_servername"
            query_uri_param pbk "$is_public_key"
            query_uri_param fp chrome
            query_uri_param sid "$is_short_id"
            uri_query=$(query_uri_query)
            is_url="$is_protocol://$(query_uri_encode "$uuid")@$is_addr:$port${uri_query}#$encoded_remark"
            ;;
        direct)
            is_can_change=(0 1 7 8)
            is_info_show=(0 1 2 13 14)
            is_info_str=($is_protocol $is_addr $port $door_addr $door_port)
            ;;
        socks)
            is_can_change=(0 1 12 4)
            is_info_show=(0 1 2 19 10)
            is_info_str=($is_protocol $is_addr $port $is_socks_user $is_socks_pass)
            encoded_user=$(query_uri_base64url "${is_socks_user}:${is_socks_pass}")
            is_url="socks://${encoded_user}@${is_addr}:${port}#$encoded_remark"
            ;;
    esac

    if [[ $is_tls_pin_profile && $tls_pin_error ]]; then
        is_url_error="无法安全生成分享链接: $tls_pin_error"
        is_url=
    fi

    if [[ $is_show_all ]]; then
        if [[ $is_url ]]; then
            ui_link "$is_url"
        elif [[ $is_url_error ]]; then
            warn "$is_config_name: $is_url_error"
        fi
        return
    fi

    if [[ $is_dont_show_info || $is_gen || $is_dont_auto_exit ]]; then return; fi

    msg "-------------- $is_config_name -------------"
    for ((i = 0; i < ${#is_info_show[@]}; i++)); do
        a=${info_list[${is_info_show[$i]}]}
        if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then tt='\t'; else tt='\t\t'; fi
        msg "$a $tt= $(ui_style "$is_value_style" "${is_info_str[$i]}")"
    done
    if [[ $is_new_install ]]; then warn "首次安装请查看项目文档: $(msg_ul https://github.com/${is_sh_repo})"; fi
    if [[ $is_url ]]; then
        msg "------------- ${info_list[12]} -------------"
        msg "$(ui_link "$is_url")"
        if [[ $is_tls_pin_profile ]]; then
            query_tls_pin_print_snippet "$is_tls_pin_profile" "$is_tls_pin_server_name"
        elif [[ $is_insecure ]]; then
            warn "某些客户端导入URL需手动将跳过证书验证设置为 true"
        fi
    elif [[ $is_url_error ]]; then
        warn "$is_url_error"
    fi
    if [[ $is_no_auto_tls ]]; then
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $port"
        msg "路径(path): $path"
    fi
    footer_msg
}
