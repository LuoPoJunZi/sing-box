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

sing_box_minimum_supported_version() {
    printf '%s\n' '1.13.19'
}

sing_box_recommended_stable_version() {
    printf '%s\n' '1.14.4'
}

sing_box_recommended_min_version() {
    sing_box_minimum_supported_version
}

caddy_recommended_stable_version() {
    printf '%s\n' '2.11.9'
}

caddy_version_has_forward_auth_risk() {
    local version

    version=$(version_normalize "$1")
    version_is_at_least "$version" 2.11.0 && version_is_less_than "$version" 2.11.5
}

version_is_prerelease() {
    local version

    version=$(version_normalize "$1")
    [[ $version == *-* ]]
}

cloudflared_version_is_blocked() {
    local version

    version=$(version_normalize "$1")
    case $version in
        2026.8.0 | 2026.8.1) return 0 ;;
        *) return 1 ;;
    esac
}

cloudflared_recommended_stable_version() {
    printf '%s\n' '2026.10.7'
}

# 2026.10.2 distrusts the compromised eMudhra keys; 2026.10.4 also
# removes command-line secrets from metrics debug endpoints.
cloudflared_minimum_safe_version() {
    printf '%s\n' '2026.10.4'
}

cloudflared_version_is_supported() {
    local version

    version=$(version_normalize "$1")
    [[ $version =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || return 1
    ! cloudflared_version_is_blocked "$version" &&
        version_is_at_least "$version" "$(cloudflared_minimum_safe_version)"
}

caddy_version_has_stream_regression() {
    [[ $(version_normalize "$1") == 2.11.6 ]]
}

# Reviewed 2026-10-31: these releases retain the affected uTLS fallback.
# Versions outside this list are unreviewed, NOT implicitly fixed.
sing_box_version_has_reported_reality_fallback_risk() {
    case $(version_normalize "$1") in
        1.14.2 | 1.14.3 | 1.14.4 | 1.15.0-alpha.10 | 1.15.0-alpha.12 | 1.15.0-alpha.13) return 0 ;;
        *) return 1 ;;
    esac
}
