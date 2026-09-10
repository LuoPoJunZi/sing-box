#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/env/defaults.sh
. src/core/node/protocol.sh
. src/core/node/build.sh
. src/core/node/create.sh
. src/core/query/parse.sh
. src/core/query/read.sh
. tests/fixtures/node-context.sh

get() { query_get "$@"; }
get_ip() { :; }
get_reality_short_id() { :; }
err() {
    echo "[node-config] $*" >&2
    return 1
}
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

for protocol in "${protocol_list[@]}" Direct; do
    (
        fixture_node_context "$protocol"
        write_create server "$protocol"
        jq -e '.inbounds | length == 1' <<< "$is_new_json" > /dev/null
        printf '%s\n' "$is_new_json" > "$tmp_dir/node.json"
        expected_password=$password
        expected_path=${path:-}
        expected_net=$net
        query_read_node "$tmp_dir/node.json"
        query_protocol_metadata
        [[ $net == "$expected_net" ]] || {
            echo "network changed: $protocol $net/$expected_net"
            exit 1
        }
        [[ ${path:-} == "$expected_path" ]] || {
            echo "path changed: $protocol"
            exit 1
        }
        case $is_protocol in
            trojan | tuic | hysteria2) [[ $password == "$expected_password" ]] ;;
        esac
    ) || {
        echo "[node-config] failed: $protocol"
        exit 1
    }
done
echo "[node-config] ok: all production protocols, special characters, read-back"
