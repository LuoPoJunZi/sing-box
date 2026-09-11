#!/bin/bash

domain_collect_pool() {
    local region="$1"
    local line d w r
    declare -A seen=()

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d w r <<< "$line"
        d="$(domain_normalize "$d")"
        [[ -z $d ]] && continue
        [[ -z $w ]] && w=5
        [[ -z $r ]] && r=global
        domain_is_disabled "$d" && continue
        [[ $r != "global" && $r != "$region" ]] && continue
        seen["$d"]="builtin|$w|$r"
    done < <(printf '%s\n' "${servername_pool[@]}")

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d w r <<< "$line"
        d="$(domain_normalize "$d")"
        [[ -z $d ]] && continue
        [[ -z $w ]] && w=4
        [[ -z $r ]] && r=global
        domain_is_disabled "$d" && continue
        [[ $r != "global" && $r != "$region" ]] && continue
        seen["$d"]="custom|$w|$r"
    done < <(if [[ -f $domain_custom_file ]]; then cat -- "$domain_custom_file"; fi)

    for d in "${!seen[@]}"; do
        echo "$d|${seen[$d]}"
    done
}

domain_weighted_pick() {
    local region="$1"
    local line d src w r
    local picks=()
    declare -A seen=()

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d src w r <<< "$line"
        [[ -z $d ]] && continue
        [[ -z $w || $w -lt 1 ]] && w=1
        [[ $w -gt 20 ]] && w=20
        for ((i = 0; i < w; i++)); do
            picks+=("$d")
        done
    done < <(domain_collect_pool "$region")

    if [[ ${#picks[@]} -eq 0 ]]; then
        return
    fi

    for ((i = 0; i < 60; i++)); do
        d="${picks[$((RANDOM % ${#picks[@]}))]}"
        [[ -z $d ]] && continue
        if [[ -z ${seen[$d]} ]]; then
            seen["$d"]=1
            echo "$d"
        fi
    done

    for d in "${picks[@]}"; do
        if [[ -z ${seen[$d]} ]]; then
            seen["$d"]=1
            echo "$d"
        fi
    done
}
