#!/bin/bash

domain_cache_write() {
    [[ ${is_dry_run:-} || ${is_gen:-} || ${is_test_json:-} ]] && return 0
    local d="$1" ok="$2"
    local now
    now="$(date +%s)"
    echo "$d|$now|$ok" >> "$domain_health_file"
    tail -n 500 "$domain_health_file" > "${domain_health_file}.tmp" 2> /dev/null || true
    mv -f "${domain_health_file}.tmp" "$domain_health_file" 2> /dev/null || true
}

domain_probe() {
    local d="$1"
    if [[ ! $(is_test domain "$d") ]]; then
        return 1
    fi

    if command -v getent > /dev/null 2>&1; then
        getent ahosts "$d" > /dev/null 2>&1 || return 1
    fi

    if command -v timeout > /dev/null 2>&1; then
        timeout 4 bash -c "exec 3<>/dev/tcp/$d/443" > /dev/null 2>&1 || return 1
    elif command -v nc > /dev/null 2>&1; then
        nc -z -w 4 "$d" 443 > /dev/null 2>&1 || return 1
    fi

    if command -v openssl > /dev/null 2>&1; then
        if command -v timeout > /dev/null 2>&1; then
            timeout 6 bash -c "echo | openssl s_client -connect $d:443 -servername $d 2>/dev/null | grep -q 'BEGIN CERTIFICATE'" || return 1
        else
            echo | openssl s_client -connect "$d:443" -servername "$d" 2> /dev/null | grep -q 'BEGIN CERTIFICATE' || return 1
        fi
    fi

    return 0
}

domain_is_healthy() {
    local d="$1"
    local ttl=21600 now ts ok last
    now="$(date +%s)"
    last="$(grep -E "^${d//./\\.}\|" "$domain_health_file" 2> /dev/null | tail -n 1)"
    if [[ $last ]]; then
        IFS='|' read -r _ ts ok <<< "$last"
        if [[ -n $ts && $((now - ts)) -lt $ttl ]]; then
            [[ $ok == "ok" ]] && return 0 || return 1
        fi
    fi

    if domain_probe "$d"; then
        domain_cache_write "$d" ok
        return 0
    fi
    domain_cache_write "$d" fail
    return 1
}
