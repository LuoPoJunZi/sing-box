#!/bin/bash

# Write-side normalization. Queries must use query_protocol_metadata instead.
node_prepare_protocol() {
    get addr
    is_lower=${1,,}
    net=
    case $is_lower in
        vmess*) is_protocol=vmess ;;
        vless* | anytls | cftunnel) is_protocol=vless ;;
        tuic* | trojan* | hysteria2*)
            is_protocol=${is_lower%%-*}
            password=${password:-$uuid}
            ;;
        shadowsocks*)
            is_protocol=shadowsocks
            net=ss
            ss_method=${ss_method:-$is_random_ss_method}
            if [[ ! $ss_password ]]; then
                if [[ $ss_method == *2022* ]]; then ss_password=$(get ss2022); else ss_password=$uuid; fi
            fi
            ;;
        direct*)
            is_protocol=direct
            net=direct
            ;;
        socks*)
            is_protocol=socks
            net=socks
            is_socks_user=${is_socks_user:-luopojunzi}
            is_socks_pass=${is_socks_pass:-$uuid}
            ;;
        *)
            err "无法识别协议: $1"
            return 1
            ;;
    esac
    [[ $net ]] && return 0
    case $is_lower in
        anytls | *reality*)
            net=reality
            is_servername=${is_servername:-$(domain_pick_for_reality)}
            is_servername=${is_servername:-$is_random_servername}
            [[ $is_private_key ]] || get_pbk
            get_reality_short_id
            ;;
        cftunnel)
            net=ws
            host=${cf_domain:-你的CF绑定域名(需修改)}
            path=${path:-/$uuid}
            ;;
        tuic* | hysteria2*) net=$is_protocol ;;
        trojan)
            net=trojan
            ;;
        *quic*) net=quic ;;
        *ws*) net=ws ;;
        *httpupgrade*) net=httpupgrade ;;
        *h2*) net=h2 ;;
        *http*)
            net=http
            [[ $host ]] && net=h2
            ;;
        *tcp* | vmess | vmess- | vless | vless-) net=tcp ;;
        *)
            err "无法识别传输协议: $1"
            return 1
            ;;
    esac
    if [[ $host && $is_lower == *tls* ]]; then path=${path:-/$uuid}; fi
    return 0
}
