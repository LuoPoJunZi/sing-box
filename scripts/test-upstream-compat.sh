#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[upstream-compat] $*"
    exit 1
}

msg() { :; }

. src/lib/version.sh
. src/core/utils/compat.sh
. src/core/admin/update.sh
. src/core/runtime/doctor.sh

[[ $(sing_box_minimum_supported_version) == 1.13.19 ]] || fail "minimum supported sing-box version changed unexpectedly"
[[ $(sing_box_recommended_stable_version) == 1.14.0 ]] || fail "recommended stable sing-box version is not 1.14.0"
[[ $(sing_box_recommended_min_version) == 1.13.19 ]] || fail "legacy minimum-version helper changed unexpectedly"
version_is_less_than 1.13.18 1.13.19 || fail "older sing-box version was not detected"
if version_is_less_than 1.13.19 1.13.19; then
    fail "equal sing-box version was treated as older"
fi
version_is_at_least v1.14.0-beta.17 1.14.0 || fail "sing-box 1.14 prerelease did not trigger preflight"
version_is_prerelease v1.15.0-alpha.1 || fail "sing-box prerelease was not detected"
if version_is_prerelease v1.14.0; then
    fail "stable sing-box version was treated as a prerelease"
fi
cloudflared_version_is_blocked 2026.8.0 || fail "cloudflared 2026.8.0 was not blocked"
cloudflared_version_is_blocked v2026.8.1 || fail "cloudflared 2026.8.1 was not blocked"
if cloudflared_version_is_blocked 2026.8.2; then
    fail "cloudflared 2026.8.2 was incorrectly blocked"
fi
if admin_update_cloudflared_version_allowed 2026.8.1; then
    fail "cloudflared update preflight allowed a blocked version"
fi
admin_update_cloudflared_version_allowed 2026.8.2 || fail "cloudflared update preflight rejected a fixed version"

cat > "$tmp_dir/config.json" << 'EOF'
{
  "dns": {
    "servers": [
      {"tag": "dns", "address": "h3://dns.google/dns-query"},
      {"tag": "fakeip", "address": "fakeip", "strategy": "ipv4_only"}
    ],
    "fakeip": {"enabled": true, "inet4_range": "198.18.0.0/15"},
    "independent_cache": true,
    "rules": [
      {"outbound": "any", "server": "dns"},
      {"type": "logical", "mode": "or", "rules": [{"ip_is_private": true}]},
      {
        "query_type": ["A"],
        "ip_cidr": ["1.1.1.0/24"],
        "strategy": "ipv4_only",
        "rule_set_ip_cidr_accept_empty": true,
        "server": "dns"
      }
    ]
  },
  "experimental": {"cache_file": {"enabled": true, "store_rdrc": true}},
  "inbounds": [{"type": "trojan", "tls": {"enabled": true, "acme": {"domain": ["example.com"]}}}]
}
EOF

report=$(compat_sing_box_issue_report "$tmp_dir/config.json")
for issue in legacy_dns_server legacy_dns_special_server legacy_dns_server_options legacy_dns_fakeip legacy_dns_outbound_rule dns_independent_cache cache_store_rdrc dns_legacy_address_filter dns_legacy_strategy dns_rule_set_accept_empty inline_acme; do
    grep -q "^${issue}" <<< "$report" || fail "compatibility report missed $issue"
done
grep -q $'^dns_legacy_address_filter\t2$' <<< "$report" || fail "nested DNS compatibility rule was not detected"
[[ $(compat_sing_box_114_rule_conflict_count "$tmp_dir/config.json") -gt 0 ]] || fail "1.14 DNS rule conflict was not detected"
compat_sing_box_114_file_requires_manual_migration "$tmp_dir/config.json" 0 || fail "manual migration requirement was not detected"

mkdir -p "$tmp_dir/conf"
cat > "$tmp_dir/safe-main.json" << 'EOF'
{"dns":{"servers":[{"tag":"dns","address":"h3://dns.google/dns-query"}]}}
EOF
cat > "$tmp_dir/conf/node.json" << 'EOF'
{"dns":{"servers":[{"tag":"dns","address":"1.1.1.1"}]}}
EOF

if compat_sing_box_114_file_requires_manual_migration "$tmp_dir/safe-main.json" 0; then
    fail "safe main-config DNS migration was marked manual"
fi
compat_sing_box_114_file_requires_manual_migration "$tmp_dir/conf/node.json" 1 || fail "node config legacy DNS was not marked manual"

is_config_json="$tmp_dir/config.json"
is_conf_dir="$tmp_dir/conf"
admin_update_core_preflight v1.13.19 || fail "1.13 update was incorrectly blocked by 1.14 rules"
if admin_update_core_preflight v1.14.0; then
    fail "1.14 update preflight allowed manual-migration configs"
fi

doctor_output=""
runtime_doctor_ok() { doctor_output+="OK:$*"$'\n'; }
runtime_doctor_warn() { doctor_output+="WARN:$*"$'\n'; }
runtime_doctor_info() { doctor_output+="INFO:$*"$'\n'; }

is_core_ver=1.13.18
if runtime_doctor_sing_box_version; then
    fail "unsupported sing-box version passed doctor"
fi
grep -q '建议升级到 1.13.19' <<< "$doctor_output" || fail "doctor did not report the minimum supported version"

doctor_output=""
is_core_ver=1.13.19
if runtime_doctor_sing_box_version; then
    fail "minimum supported sing-box version was treated as recommended"
fi
grep -q '推荐稳定版 1.14.0' <<< "$doctor_output" || fail "doctor did not recommend sing-box 1.14.0"

doctor_output=""
is_core_ver=1.14.0
runtime_doctor_sing_box_version || fail "recommended sing-box stable version failed doctor"
grep -q '推荐稳定版基线 1.14.0' <<< "$doctor_output" || fail "doctor did not accept sing-box 1.14.0"

doctor_output=""
is_core_ver=1.15.0-alpha.1
if runtime_doctor_sing_box_version; then
    fail "sing-box prerelease passed the stable-version doctor check"
fi
grep -q '预发布版' <<< "$doctor_output" || fail "doctor did not warn about a sing-box prerelease"

echo "[upstream-compat] ok"
