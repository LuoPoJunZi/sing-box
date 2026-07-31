#!/bin/bash

get_ip() {
    if [[ $ip || $is_no_auto_tls || $is_gen || $is_dont_get_ip ]]; then
        return
    fi
    ip=$(curl -s4m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    if [[ ! $ip ]]; then
        ip=$(curl -s6m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    fi
    if [[ ! $ip ]]; then
        err "获取服务器 IP 失败，请检查网络.."
    fi
}

get_port() {
    is_count=0
    while :; do
        ((is_count++))
        if [[ $is_count -ge 233 ]]; then
            err "自动获取可用端口失败次数达到 233 次, 请检查端口占用情况."
        fi
        tmp_port=$(shuf -i 20000-65535 -n 1)
        if [[ ! $(is_test port_used "$tmp_port") && $tmp_port != "$port" ]]; then
            break
        fi
    done

    if [[ $tmp_port ]]; then
        firewall_allow "$tmp_port"
    fi
}
