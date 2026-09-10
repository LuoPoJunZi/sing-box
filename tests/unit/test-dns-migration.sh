#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[dns-migration] $*"
    exit 1
}

is_config_json="$tmp_dir/config.json"
cat > "$is_config_json" << 'EOF'
{
  "dns": {
    "servers": [
      {"tag": "dns", "address": "h3://dns.google/dns-query", "address_resolver": "local"},
      {"tag": "backup", "address": "1.1.1.1"},
      {"tag": "local", "address": "local"}
    ]
  },
  "route": {"default_domain_resolver": "dns"}
}
EOF

. src/core/utils/dns.sh

[[ $(dns_legacy_server_count "$is_config_json") == 3 ]] || fail "legacy server count is incorrect"
dns_build_modern_config "$is_config_json" "$tmp_dir/modern.json"
[[ $(jq -r '.dns.servers[0].type' "$tmp_dir/modern.json") == h3 ]] || fail "h3 type was not migrated"
[[ $(jq -r '.dns.servers[0].server' "$tmp_dir/modern.json") == dns.google ]] || fail "h3 server was not migrated"
[[ $(jq -r '.dns.servers[0].path' "$tmp_dir/modern.json") == /dns-query ]] || fail "h3 path was not migrated"
[[ $(jq -r '.dns.servers[1].type' "$tmp_dir/modern.json") == udp ]] || fail "plain DNS was not migrated"
[[ $(jq -r '.dns.servers[2].type' "$tmp_dir/modern.json") == local ]] || fail "local DNS was not migrated"
if dns_config_uses_legacy_servers "$tmp_dir/modern.json"; then
    fail "modern config still contains legacy address fields"
fi

echo "[dns-migration] ok"
