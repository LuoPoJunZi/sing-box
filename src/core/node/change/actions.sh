#!/bin/bash

write_change_key_action() {
    is_new_private_key=$3
    is_new_public_key=$4
    if [[ ! $is_reality ]]; then
        err "($is_config_file) 不支持更改密钥."
        return 1
    fi
    if [[ $is_dry_run ]]; then
        if [[ $is_auto ]]; then
            msg "DRY-RUN: 将自动生成新的 Reality 密钥对并写入配置: $is_config_file"
        else
            msg "DRY-RUN: 将更新 Reality 密钥 -> config=$is_config_file"
        fi
        return
    fi
    if [[ $is_auto ]]; then
        get_pbk || return 1
        add "$net"
    else
        if [[ $is_new_private_key && ! $is_new_public_key ]]; then
            err "无法找到 Public key."
            return 1
        fi
        if [[ ! $is_new_private_key ]]; then ask string is_new_private_key "请输入新 Private key"; fi
        if [[ ! $is_new_public_key ]]; then ask string is_new_public_key "请输入新 Public key"; fi
        if [[ $is_new_private_key == "$is_new_public_key" ]]; then
            err "Private key 和 Public key 不能一样."
            return 1
        fi
        if [[ ! $is_new_private_key =~ ^[A-Za-z0-9_-]{43}=?$ ||
            ! $is_new_public_key =~ ^[A-Za-z0-9_-]{43}=?$ ]]; then
            err "Reality 密钥必须为编码后的 32 字节密钥"
            return 1
        fi
        local candidate
        candidate=$(jq --arg private "$is_new_private_key" --arg public "$is_new_public_key" '
            .inbounds[0].tls.reality.private_key = $private
            | .outbounds = ([.outbounds[]? | select(((.tag // "") | startswith("public_key_")) | not)]
                + [{tag:("public_key_" + $public),type:"direct"}])
        ' "$is_conf_dir/$is_config_file") || return 1
        snapshot_ensure "write-reality-key" || return 1
        node_commit_config node "$candidate" "$is_config_file" "$is_config_file" || return 1
        is_private_key=$is_new_private_key
        is_public_key=$is_new_public_key
        is_test_json=
        manage restart &
        info "$is_config_file"
    fi
}

write_change_port_action() {
    is_new_port=$3
    if [[ $host && ! $is_caddy || $is_no_auto_tls ]]; then
        err "($is_config_file) 不支持更改端口, 因为没啥意义."
    fi
    if [[ $is_new_port && ! $is_auto ]]; then
        if [[ ! $(is_test port $is_new_port) ]]; then err "请输入正确的端口, 可选(1-65535)"; fi
        if [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]]; then err "无法使用 ($is_new_port) 端口"; fi
    fi
    if [[ $is_auto ]]; then
        get_port
        is_new_port=$tmp_port
    fi
    if [[ ! $is_new_port ]]; then ask string is_new_port "请输入新端口"; fi
    if [[ $is_caddy && $host ]]; then
        if [[ $is_dry_run ]]; then
            msg "DRY-RUN: 将更新 Caddy 端口映射 -> host=$host https_port=$is_new_port"
            msg "DRY-RUN: 将重启 caddy"
            return
        fi
        net=$is_old_net
        is_https_port=$is_new_port
        load caddy.sh
        caddy_config $net
        manage restart caddy &
        info
    else
        add $net $is_new_port
    fi
}

write_change_sni_action() {
    is_new_servername=$3
    if [[ ! $is_reality ]]; then err "($is_config_file) 不支持更改 serverName."; fi
    if [[ $is_auto ]]; then is_new_servername=$(domain_pick_for_reality); fi
    if [[ ! $is_new_servername ]]; then is_new_servername=$is_random_servername; fi
    if [[ ! $is_new_servername ]]; then ask string is_new_servername "请输入新的 serverName"; fi
    is_servername=$is_new_servername
    add $net
}

write_change_web_action() {
    is_new_proxy_site=$3
    if [[ ! $is_caddy && ! $host ]]; then err "($is_config_file) 不支持更改伪装网站."; fi
    if [[ ! -f $is_caddy_conf/${host}.conf.add ]]; then err "无法配置伪装网站."; fi
    if [[ ! $is_new_proxy_site ]]; then ask string is_new_proxy_site "请输入新的伪装网站 (例如 example.com)"; fi
    proxy_site=$(sed 's#^.*//##;s#/$##' <<< $is_new_proxy_site)
    if [[ $is_dry_run ]]; then
        msg "DRY-RUN: 将更新伪装网站 -> host=$host proxy_site=$proxy_site"
        msg "DRY-RUN: 将重启 caddy"
        return
    fi
    load caddy.sh
    caddy_config proxy
    manage restart caddy &
    msg "\n已更新伪装网站为: $(_green $proxy_site) \n"
}
