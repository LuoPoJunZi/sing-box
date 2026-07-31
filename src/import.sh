#!/bin/bash

is_xray_sh=/etc/xray/sh/src/core.sh
is_v2ray_sh=/etc/v2ray/sh/src/core.sh
is_xray_conf=/etc/xray/conf
is_v2ray_conf=/etc/v2ray/conf

in_conf() {
    is_conf_args=$(jq '.inbounds[0]|.protocol,.port,(.settings|(.clients[0]|.id,.password),.method,.password,.port,.address,(.accounts[0]|.user,.pass)),(.streamSettings|.network,.security,.tcpSettings.header.type,(.wsSettings|.path,.headers.Host),(.httpSettings|.path,.host[0]),(.realitySettings|.serverNames[0],.publicKey,.privateKey))' "$1")
    [[ $? != 0 ]] && warn "无法读取此文件: $1" && return

    is_up_var_set=(null is_protocol port uuid trojan_password ss_method ss_password door_port door_addr is_socks_user is_socks_pass net is_reality net_type ws_path ws_host h2_path h2_host is_servername is_public_key is_private_key)
    i=0
    local conf_items=()
    mapfile -t conf_items < <(sed 's/""/null/g;s/"//g' <<< "$is_conf_args")
    for v in "${conf_items[@]}"; do
        ((i++))
        export "${is_up_var_set[$i]}=${v}"
    done
    for v in "${is_up_var_set[@]}"; do
        [[ ${!v} == 'null' ]] && unset "$v"
    done

    path="${ws_path}${h2_path}"
    host="${ws_host}${h2_host}"
    [[ ! $uuid ]] && uuid=$trojan_password

    if [[ $host ]]; then
        if [[ $is_caddy && -f $is_caddy_conf/$host.conf ]]; then
            tmp_tlsport=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
        fi
        [[ $tmp_tlsport ]] && https_port=$tmp_tlsport
        add "$is_protocol-$net-tls"
    else
        case $is_protocol in
            vmess | vless)
                [[ $net_type == "http" ]] && {
                    net=http
                    is_tips_msg="新配置文件名: (VMess-HTTP-$port.json)"
                }
                [[ $is_reality == "reality" ]] && net=reality
                add "$net"
                ;;
            dokodemo-door)
                add door
                is_tips_msg="新配置文件名: (Direct-$port.json)"
                ;;
            *socks*)
                add "$is_protocol"
                ;;
            *)
                is_not_in_conf=1
                msg "不支持导入 $1"
                ;;
        esac
    fi
    [[ ! $is_not_in_conf ]] && msg "导入: $1 $is_tips_msg" && rm -f -- "$1"
}

is_change=1
is_dont_auto_exit=1
is_dont_test_host=1

if [[ -f $is_xray_sh && -d $is_xray_conf ]]; then
    mapfile -t is_list < <(find "$is_xray_conf" -maxdepth 1 -type f -name '*.json' | grep -E -iv 'kcp|grpc|dynamic|quic')
fi
if [[ -f $is_v2ray_sh && -d $is_v2ray_conf ]]; then
    mapfile -t is_v2ray_list < <(find "$is_v2ray_conf" -maxdepth 1 -type f -name '*.json' | grep -E -iv 'kcp|grpc|dynamic|quic')
    is_list+=("${is_v2ray_list[@]}")
fi

is_list_text="${is_list[*]}"
[[ $is_list_text == *xray* ]] && is_xray_in=1
[[ $is_list_text == *v2ray* ]] && is_v2ray_in=1

[[ $is_xray_in ]] && xray stop > /dev/null 2>&1
[[ $is_v2ray_in ]] && v2ray stop > /dev/null 2>&1

if [[ ${#is_list[@]} -gt 0 ]]; then
    msg "开始导入配置..."
    for i in "${is_list[@]}"; do
        in_conf "$i" &
    done
    wait
    is_dont_auto_exit=
    manage restart &
    [[ $is_xray_in ]] && xray restart > /dev/null 2>&1 &
    [[ $is_v2ray_in ]] && v2ray restart > /dev/null 2>&1 &
    [[ ${is_list_text,,} == *tls* && $is_caddy ]] && manage restart caddy &
else
    err "没有找到可导入的配置..."
fi
