#!/bin/bash

compat_sing_box_issue_report() {
    local config_file=$1

    [[ -f $config_file ]] || return 1
    jq -r '
        [
            ["legacy_dns_server", ([.dns.servers[]? | select(type == "object" and has("address"))] | length)],
            ["legacy_dns_special_server", ([.dns.servers[]? | select(
                type == "object" and
                (.address? | type) == "string" and
                (.address == "fakeip" or (.address | test("^(dhcp|rcode)://")))
            )] | length)],
            ["legacy_dns_server_options", ([.dns.servers[]? | select(
                type == "object" and has("address") and (has("strategy") or has("client_subnet"))
            )] | length)],
            ["legacy_dns_fakeip", (if ((.dns? | type) == "object" and (.dns | has("fakeip"))) then 1 else 0 end)],
            ["legacy_dns_outbound_rule", ([.dns.rules[]? | .. | objects | select(has("outbound"))] | length)],
            ["dns_independent_cache", (if ((.dns? | type) == "object" and (.dns | has("independent_cache"))) then 1 else 0 end)],
            ["cache_store_rdrc", (if ((.experimental.cache_file? | type) == "object" and (.experimental.cache_file | has("store_rdrc"))) then 1 else 0 end)],
            ["dns_legacy_address_filter", ([.dns.rules[]? | .. | objects | select(
                (has("ip_cidr") or has("ip_is_private")) and
                ((.match_response // false) != true)
            )] | length)],
            ["dns_legacy_strategy", ([.dns.rules[]? | .. | objects | select(has("strategy"))] | length)],
            ["dns_rule_set_accept_empty", ([.dns.rules[]? | .. | objects | select(has("rule_set_ip_cidr_accept_empty"))] | length)],
            ["inline_acme", ([.. | objects | .tls? | select(type == "object" and has("acme"))] | length)]
        ]
        | .[]
        | select(.[1] > 0)
        | @tsv
    ' "$config_file" 2> /dev/null
}

compat_sing_box_114_rule_conflict_count() {
    local config_file=$1

    jq -r '
        ([.dns.rules[]? | .. | objects | select(has("query_type") or has("ip_version"))] | length) as $query_rules
        | ([.dns.rules[]? | .. | objects | select(
            (
                has("strategy") or
                has("rule_set_ip_cidr_accept_empty") or
                ((has("ip_cidr") or has("ip_is_private")) and ((.match_response // false) != true))
            )
        )] | length) as $legacy_rules
        | if ($query_rules > 0 and $legacy_rules > 0) then $legacy_rules else 0 end
    ' "$config_file" 2> /dev/null || printf '0\n'
}

compat_sing_box_114_manual_count() {
    local config_file=$1 include_all_legacy=${2:-0}

    jq -r --argjson include_all_legacy "$include_all_legacy" '
        [.dns.servers[]? | select(type == "object" and has("address"))] as $legacy_servers
        | ([$legacy_servers[] | select(
            (has("strategy") or has("client_subnet")) or
            ((.address | type) != "string") or
            (.address == "fakeip") or
            ((.address | type) == "string" and (.address | test("^(dhcp|rcode)://"))) or
            ((.address | type) == "string" and (.address | test("^[A-Za-z][A-Za-z0-9+.-]*://")) and ((.address | test("^(tcp|udp|tls|https|quic|h3)://")) | not))
        )] | length) as $manual_servers
        | (if ((.dns? | type) == "object" and (.dns | has("fakeip"))) then 1 else 0 end) as $legacy_fakeip
        | if $include_all_legacy == 1 then ($legacy_servers | length) + $legacy_fakeip else $manual_servers + $legacy_fakeip end
    ' "$config_file" 2> /dev/null || printf '0\n'
}

compat_sing_box_114_file_requires_manual_migration() {
    local config_file=$1 include_all_legacy=${2:-0}
    local manual_count conflict_count

    manual_count=$(compat_sing_box_114_manual_count "$config_file" "$include_all_legacy")
    conflict_count=$(compat_sing_box_114_rule_conflict_count "$config_file")
    [[ $manual_count =~ ^[0-9]+$ && $conflict_count =~ ^[0-9]+$ ]] || return 0
    ((manual_count + conflict_count > 0))
}

compat_sing_box_114_manual_files() {
    local main_config=$1 conf_dir=$2 config_file

    if [[ -f $main_config ]] && compat_sing_box_114_file_requires_manual_migration "$main_config" 0; then
        printf '%s\n' "$main_config"
    fi
    [[ -d $conf_dir ]] || return
    while IFS= read -r config_file; do
        if compat_sing_box_114_file_requires_manual_migration "$config_file" 1; then
            printf '%s\n' "$config_file"
        fi
    done < <(find "$conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort)
}
