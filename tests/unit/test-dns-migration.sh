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

# Verify dns_set_server preserves custom case-sensitive DoH/H3 paths and transactional commits.
. src/lib/version.sh
. src/core/utils/log.sh
. src/core/node/transaction.sh

msg() { :; }
warn() { :; }
_green() { printf '%s' "$*"; }
err() { return 1; }
manage() { printf 'restart\n' >> "$tmp_dir/restarts"; }
snapshot_ensure() { printf '%s\n' "$1" >> "$tmp_dir/snapshots"; }

dns_set_server 'HTTPS://DNS.Example.COM/CustomPath/TokenAbC'
[[ $is_dns_type == https && $is_dns_use == dns.example.com && $is_dns_path == '/CustomPath/TokenAbC' ]] || fail "custom DoH path or case was corrupted"
dns_set_server 'tls://DNS.Google/ignored-path'
[[ $is_dns_type == tls && $is_dns_use == dns.google && -z $is_dns_path ]] || fail "non-HTTP DNS scheme retained path"

is_core=sing-box
is_core_ver=1.14.4
is_conf_dir="$tmp_dir/conf"
mkdir -p "$is_conf_dir" "$tmp_dir/logs"
is_log_dir="$tmp_dir/logs"
is_config_json="$tmp_dir/live-main.json"
printf '%s\n' '{"log":{"level":"info"},"dns":{},"outbounds":[{"tag":"direct","type":"direct"}]}' > "$is_config_json"
reject_check=0
fake_core() { [[ $1 == check && $reject_check -eq 0 ]]; }
is_core_bin=fake_core

dns_set set 'https://dns.example.com/CustomPath'
wait
jq -e '.dns.servers[0] == {tag:"dns",type:"https",server:"dns.example.com",domain_resolver:"local",path:"/CustomPath"} and .route.default_domain_resolver == "dns"' "$is_config_json" > /dev/null || fail "dns_set did not commit custom DoH path"

before_valid=$(cat "$is_config_json")
reject_check=1
if dns_set 11; then fail "dns_set ignored core validation failure"; fi
[[ $(cat "$is_config_json") == "$before_valid" ]] || fail "failed dns_set mutated main config"
if log_set debug; then fail "log_set ignored core validation failure"; fi
[[ $(cat "$is_config_json") == "$before_valid" ]] || fail "failed log_set mutated main config"

reject_check=0
log_set warn
wait
jq -e '.log.level == "warn" and .log.timestamp == true' "$is_config_json" > /dev/null || fail "log_set did not update log level"

printf 'corrupt-json\n' > "$is_config_json"
if dns_set 11 2> /dev/null; then fail "dns_set succeeded on corrupt JSON"; fi
[[ $(cat "$is_config_json") == 'corrupt-json' ]] || fail "dns_set truncated corrupt config.json"

echo "[dns-migration] ok"
