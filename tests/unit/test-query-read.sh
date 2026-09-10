#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/query/read.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
jq -n --arg password $'literal "null" // \\ newline\nend' '
 {inbounds:[{type:"trojan", listen_port:443, users:[{password:$password}],
 transport:{type:"ws", path:"/a//b"}}]}
' > "$tmp_dir/node.json"
query_read_node "$tmp_dir/node.json"
[[ $password == $'literal "null" // \\ newline\nend' && $path == /a//b ]]
is_reality=1
host=stale.example.com
query_read_node "$tmp_dir/node.json"
[[ -z ${is_reality:-} && -z ${host:-} ]]
printf '{invalid' > "$tmp_dir/bad.json"
if query_read_node "$tmp_dir/bad.json"; then exit 1; fi
[[ -z ${password:-} ]]
jq -n '{inbounds:[{type:"trojan",users:[{password:"\u001e"}]}]}' > "$tmp_dir/bad.json"
if query_read_node "$tmp_dir/bad.json"; then exit 1; fi
echo "[query-read] ok"
