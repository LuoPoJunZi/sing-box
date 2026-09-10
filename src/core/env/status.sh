#!/bin/bash

# Read-only probes. Explicitly refresh before rendering a new command invocation.
runtime_refresh_status() {
    unset is_core_stop is_caddy_stop is_caddy is_caddy_status is_caddy_ver
    is_caddy_service=$(systemctl list-units --full -all 2> /dev/null | grep caddy.service || true)
    is_core_ver=$("$is_core_bin" version 2> /dev/null | awk 'NR == 1 {print $3; exit}' || true)
    if systemctl is-active --quiet "$is_core" 2> /dev/null || pgrep -f "$is_core_bin" > /dev/null; then
        is_core_status="$(ui_ok_badge) $(_green "running")"
    else
        is_core_status="$(ui_stop_badge) $(_red "stopped")"
        is_core_stop=1
    fi

    if [[ -f $is_caddy_bin && -d $is_caddy_dir && $is_caddy_service ]]; then
        is_caddy=1
        is_caddy_ver=$($is_caddy_bin version 2> /dev/null | awk 'NR == 1 {print $1; exit}')
        is_tmp_http_port=$(grep -E '^ {2,}http_port|^http_port' "$is_caddyfile" 2> /dev/null | grep -oE '[0-9]+')
        is_tmp_https_port=$(grep -E '^ {2,}https_port|^https_port' "$is_caddyfile" 2> /dev/null | grep -oE '[0-9]+')
        [[ $is_tmp_http_port ]] && is_http_port=$is_tmp_http_port
        [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port

        if systemctl is-active --quiet caddy 2> /dev/null || pgrep -f "$is_caddy_bin" > /dev/null; then
            is_caddy_status="$(ui_ok_badge) $(_green "running")"
        else
            is_caddy_status="$(ui_stop_badge) $(_red "stopped")"
            is_caddy_stop=1
        fi
    fi
}
