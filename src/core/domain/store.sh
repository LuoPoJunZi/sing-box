#!/bin/bash

domain_init_store() {
    domain_custom_file="$is_sh_dir/domain_custom.list"
    domain_disabled_file="$is_sh_dir/domain_disabled.list"
    domain_health_file="$is_sh_dir/domain_health.cache"
    domain_recent_file="$is_sh_dir/domain_recent.list"

    [[ ${is_dry_run:-} || ${is_gen:-} || ${is_test_json:-} ]] && return 0

    mkdir -p "$is_sh_dir"
    [[ -f $domain_custom_file ]] || : > "$domain_custom_file"
    [[ -f $domain_disabled_file ]] || : > "$domain_disabled_file"
    [[ -f $domain_health_file ]] || : > "$domain_health_file"
    [[ -f $domain_recent_file ]] || : > "$domain_recent_file"
}

domain_normalize() {
    local v="$1"
    v="${v#http://}"
    v="${v#https://}"
    v="${v%%/*}"
    v="${v%%:*}"
    echo "${v,,}"
}

domain_sanitize_region() {
    case "${1,,}" in
        us | eu | apac | global) echo "${1,,}" ;;
        "" | auto) echo "$(domain_detect_region)" ;;
        *) echo "global" ;;
    esac
}

domain_detect_region() {
    if [[ $SB_DOMAIN_REGION ]]; then
        domain_sanitize_region "$SB_DOMAIN_REGION"
        return
    fi
    local tz
    tz="$(timedatectl show -p Timezone --value 2> /dev/null)"
    case "$tz" in
        Asia/* | Australia/* | Pacific/*) echo "apac" ;;
        Europe/* | Africa/*) echo "eu" ;;
        America/*) echo "us" ;;
        *) echo "global" ;;
    esac
}

domain_is_disabled() {
    local d="$1"
    grep -Fxq "$d" "$domain_disabled_file" 2> /dev/null
}
