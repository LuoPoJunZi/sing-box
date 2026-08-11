#!/bin/bash

dns_set() {
    if [[ $(printf '%s\n' '1.11.99' "$is_core_ver" | sort -V | head -n 1) == '1.11.99' ]]; then
        is_dns_new=1
    fi
    if [[ $1 ]]; then
        case ${1,,} in
            11 | 1111) is_dns_use=${is_dns_list[0]} ;;
            88 | 8888) is_dns_use=${is_dns_list[1]} ;;
            gg | google) is_dns_use=${is_dns_list[2]} ;;
            cf | cloudflare) is_dns_use=${is_dns_list[3]} ;;
            nosex | family) is_dns_use=${is_dns_list[4]} ;;
            set) [[ $2 ]] && is_dns_use=${2,,} || ask string is_dns_use "请输入 DNS: " ;;
            none) is_dns_use=none ;;
            *) err "无法识别 DNS 参数" ;;
        esac
    else
        is_tmp_list=("${is_dns_list[@]}")
        ask list is_dns_use "" "\n请选择 DNS:\n"
        [[ $is_dns_use == "set" ]] && ask string is_dns_use "请输入 DNS: "
    fi
    is_dns_use_bak=$is_dns_use
    if [[ $is_dns_use == "none" ]]; then
        json_write_config "$(jq '.|.dns={}|del(.route.default_domain_resolver)' "$is_config_json")"
    else
        if [[ $is_dns_new ]]; then
            dns_set_server "$is_dns_use"
            json_write_config "$(jq --arg type "$is_dns_type" --arg server "$is_dns_use" '.dns.servers=[{tag:"dns",type:$type,server:$server,domain_resolver:"local"},{tag:"local",type:"local"}]|.route.default_domain_resolver="dns"' "$is_config_json")"
        else
            json_write_config "$(jq --arg address "$is_dns_use" '.dns.servers=[{address:$address,address_resolver:"local"},{tag:"local",address:"local"}]' "$is_config_json")"
        fi
    fi
    manage restart &
    msg "\n已更新 DNS 为: $(_green $is_dns_use_bak)\n"
}

dns_set_server() {
    local dns_value=${1,,}

    if [[ $dns_value == *://* ]]; then
        is_dns_type=${dns_value%%://*}
        is_dns_use=${dns_value#*://}
        is_dns_use=${is_dns_use%%/*}
        case $is_dns_type in
            tcp | udp | tls | https | quic | h3) ;;
            *) err "无法识别 DNS 类型!" ;;
        esac
    else
        is_dns_use=$dns_value
        is_dns_type=udp
    fi
}

dns_legacy_server_count() {
    local config_file=${1:-$is_config_json}

    [[ -f $config_file ]] || {
        printf '0\n'
        return
    }
    jq -r '[.dns.servers[]? | select(type == "object" and has("address"))] | length' "$config_file" 2> /dev/null || printf '0\n'
}

dns_config_uses_legacy_servers() {
    local count

    count=$(dns_legacy_server_count "${1:-$is_config_json}")
    [[ $count =~ ^[0-9]+$ && $count -gt 0 ]]
}

dns_build_modern_config() {
    local input_file=$1 output_file=$2

    jq '
        def modern_dns_server:
            . as $old |
            if (has("address") | not) then
                .
            elif ($old.address | type) != "string" or $old.address == "" then
                error("unsupported legacy DNS address")
            else
                ($old | del(.address, .address_resolver)) as $base |
                ($old.address_resolver // "") as $resolver |
                if $old.address == "local" then
                    $base + {type: "local"}
                elif ($old.address | test("^[A-Za-z][A-Za-z0-9+.-]*://")) then
                    ($old.address | capture("^(?<type>tcp|udp|tls|https|quic|h3)://(?<server>[^/]+)(?<path>/.*)?$")) as $parsed |
                    $base + {type: $parsed.type, server: $parsed.server} +
                    (if $resolver != "" then {domain_resolver: $resolver} else {} end) +
                    (if (($parsed.path // "") != "" and ($parsed.type == "https" or $parsed.type == "h3")) then {path: $parsed.path} else {} end)
                else
                    $base + {type: "udp", server: $old.address} +
                    (if $resolver != "" then {domain_resolver: $resolver} else {} end)
                end
            end;

        .dns.servers |= map(modern_dns_server)
    ' "$input_file" > "$output_file"
}
