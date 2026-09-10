#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
systemctl() {
    case $1 in list-units | is-active) return 1 ;; esac
    printf 'mutation: %s\n' "$*" >> "$tmp_dir/mutations"
    return 1
}
pgrep() { return 1; }
install_service() { echo mutation >> "$tmp_dir/mutations"; }
# No installed core or systemd is needed to load the local modules.
. src/init.sh help
[[ ! -e $tmp_dir/mutations ]]
declare -F node_build_config query_read_node runtime_doctor > /dev/null
runtime_refresh_status
[[ ! -e $tmp_dir/mutations ]]
echo "[init-readonly] ok"
