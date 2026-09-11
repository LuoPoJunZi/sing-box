#!/bin/bash

domain_recent_contains() {
    local d="$1"
    tail -n 8 "$domain_recent_file" 2> /dev/null | grep -Fq "|$d"
}

domain_mark_recent() {
    [[ ${is_dry_run:-} || ${is_gen:-} || ${is_test_json:-} ]] && return 0
    local d="$1" now
    now="$(date +%s)"
    echo "$now|$d" >> "$domain_recent_file"
    tail -n 50 "$domain_recent_file" > "${domain_recent_file}.tmp" 2> /dev/null || true
    mv -f "${domain_recent_file}.tmp" "$domain_recent_file" 2> /dev/null || true
}

domain_pick_for_reality() {
    domain_init_store
    local region="${1:-$(domain_detect_region)}"
    local d selected
    local candidates=()
    mapfile -t candidates < <(domain_weighted_pick "$region")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "$is_random_servername"
        return
    fi

    for d in "${candidates[@]}"; do
        domain_recent_contains "$d" && continue
        if domain_is_healthy "$d"; then
            selected="$d"
            break
        fi
    done

    if [[ ! $selected ]]; then
        for d in "${candidates[@]}"; do
            if domain_is_healthy "$d"; then
                selected="$d"
                break
            fi
        done
    fi

    if [[ ! $selected ]]; then
        selected="${candidates[0]}"
    fi

    domain_mark_recent "$selected"
    echo "$selected"
}
