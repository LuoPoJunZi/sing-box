#!/bin/bash

version_normalize() {
    local version=${1#v}

    printf '%s\n' "${version%%[[:space:]]*}"
}

version_is_less_than() {
    local current minimum first

    current=$(version_normalize "$1")
    minimum=$(version_normalize "$2")
    [[ $current && $minimum && $current != "$minimum" ]] || return 1
    first=$(printf '%s\n' "$current" "$minimum" | sort -V | head -n 1)
    [[ $first == "$current" ]]
}

version_is_at_least() {
    local current minimum

    current=$(version_normalize "$1")
    minimum=$(version_normalize "$2")
    [[ $current && $minimum ]] || return 1
    ! version_is_less_than "$current" "$minimum"
}

sing_box_recommended_min_version() {
    printf '%s\n' '1.13.19'
}

cloudflared_version_is_blocked() {
    local version

    version=$(version_normalize "$1")
    case $version in
        2026.8.0 | 2026.8.1) return 0 ;;
        *) return 1 ;;
    esac
}
