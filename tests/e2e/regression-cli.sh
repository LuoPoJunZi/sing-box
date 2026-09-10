#!/usr/bin/env bash
set -euo pipefail

SB_BIN="${SB_BIN:-sb}"
CONF_DIR="${CONF_DIR:-/etc/sing-box/conf}"
ALLOW_WRITES="${ALLOW_WRITES:-0}"

if ! command -v "$SB_BIN" > /dev/null 2>&1; then
    echo "[regression-cli] command not found: $SB_BIN"
    echo "[regression-cli] set SB_BIN=/path/to/sb or install the script first"
    exit 1
fi

run() {
    echo
    echo "[regression-cli] >>> $*"
    "$@"
}

run_with_input() {
    local input="$1"
    shift
    echo
    echo "[regression-cli] >>> printf input | $*"
    printf "%b" "$input" | "$@"
}

run_no_color() {
    echo
    echo "[regression-cli] >>> NO_COLOR=1 $*"
    NO_COLOR=1 "$@"
}

first_config_name() {
    find "$CONF_DIR" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2> /dev/null | sort | head -n 1
}

representative_config_names() {
    local file="" signature=""

    while IFS= read -r file; do
        signature=$(jq -r '(.inbounds[0].type // "unknown") + ":" + (.inbounds[0].transport.type // "none") + ":" + ((.inbounds[0].tls.reality.enabled // false) | tostring)' "$file" 2> /dev/null || true)
        printf '%s\t%s\n' "$signature" "$(basename "$file")"
    done < <(find "$CONF_DIR" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort) |
        sort -k1,1 -k2,2 |
        awk -F '\t' '!seen[$1]++ { print $2 }'
}

echo "[regression-cli] using command: $SB_BIN"
echo "[regression-cli] host: $(uname -a 2> /dev/null || true)"
if [[ -f /etc/os-release ]]; then
    os_name="$(grep -E '^PRETTY_NAME=' /etc/os-release 2> /dev/null | cut -d= -f2- | tr -d '"')"
    echo "[regression-cli] os: ${os_name:-unknown}"
fi

# Read-only commands. These should be safe on production hosts.
run "$SB_BIN" help
run "$SB_BIN" version
run "$SB_BIN" status
run_with_input "0\n" "$SB_BIN" main
run "$SB_BIN" doctor
run_no_color "$SB_BIN" doctor
run "$SB_BIN" backup list
run "$SB_BIN" manifest
run "$SB_BIN" domain list
run "$SB_BIN" domain pick
run "$SB_BIN" all
run "$SB_BIN" dry-run uninstall

config_name="$(first_config_name || true)"
if [[ -n $config_name ]]; then
    run "$SB_BIN" info "$config_name"
    run "$SB_BIN" url "$config_name"
    run "$SB_BIN" dry-run change "$config_name" port auto
    run "$SB_BIN" dry-run change "$config_name" sni auto
else
    echo
    echo "[regression-cli] no existing config found under $CONF_DIR; skipping info/url/change dry-run checks"
fi

mapfile -t representative_configs < <(representative_config_names || true)
for representative_config in "${representative_configs[@]}"; do
    if [[ -z $representative_config || $representative_config == "$config_name" ]]; then
        continue
    fi
    echo
    echo "[regression-cli] checking representative protocol config: $representative_config"
    run "$SB_BIN" info "$representative_config"
    run "$SB_BIN" url "$representative_config"
done

if [[ $ALLOW_WRITES == "1" ]]; then
    echo
    echo "[regression-cli] write checks enabled"
    run "$SB_BIN" backup create regression-cli
    run "$SB_BIN" backup list
else
    echo
    echo "[regression-cli] write checks skipped; set ALLOW_WRITES=1 on a disposable VPS to include backup create"
fi

echo
echo "[regression-cli] checks passed"
