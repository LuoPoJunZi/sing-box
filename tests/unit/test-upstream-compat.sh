#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
[[ $(sing_box_recommended_stable_version) == 1.14.2 ]] || fail "recommended stable sing-box version is not 1.14.2"
[[ $(sing_box_recommended_min_version) == 1.13.19 ]] || fail "legacy minimum-version helper changed unexpectedly"
[[ $(caddy_recommended_stable_version) == 2.11.4 ]] || fail "recommended Caddy baseline is not 2.11.4"
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
caddy_version_has_forward_auth_risk v2.11.0 || fail "Caddy 2.11.0 forward_auth risk was not detected"
caddy_version_has_forward_auth_risk 2.11.4 || fail "Caddy 2.11.4 forward_auth risk was not detected"
if caddy_version_has_forward_auth_risk 2.10.2 || caddy_version_has_forward_auth_risk 2.11.5; then
    fail "unaffected Caddy version was marked for the 2.11 forward_auth risk"
fi

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
  "route": {
    "rule_set": [
      {"type": "remote", "tag": "legacy", "url": "https://example.com/legacy.srs", "download_detour": "direct"},
      {"type": "remote", "tag": "implicit", "url": "https://example.com/implicit.srs"}
    ]
  },
  "inbounds": [{"type": "trojan", "tls": {"enabled": true, "acme": {"domain": ["example.com"]}}}]
}
EOF

report=$(compat_sing_box_issue_report "$tmp_dir/config.json")
for issue in legacy_dns_server legacy_dns_special_server legacy_dns_server_options legacy_dns_fakeip legacy_dns_outbound_rule dns_independent_cache cache_store_rdrc dns_legacy_address_filter dns_legacy_strategy dns_rule_set_accept_empty legacy_rule_set_download_detour implicit_rule_set_http_client inline_acme; do
    grep -q "^${issue}" <<< "$report" || fail "compatibility report missed $issue"
done
grep -q $'^dns_legacy_address_filter\t2$' <<< "$report" || fail "nested DNS compatibility rule was not detected"
grep -q $'^implicit_rule_set_http_client\t2$' <<< "$report" || fail "implicit remote rule-set HTTP clients were not counted"
[[ $(compat_sing_box_114_rule_conflict_count "$tmp_dir/config.json") -gt 0 ]] || fail "1.14 DNS rule conflict was not detected"
compat_sing_box_114_file_requires_manual_migration "$tmp_dir/config.json" 0 || fail "manual migration requirement was not detected"

cat > "$tmp_dir/explicit-http-client.json" << 'EOF'
{
  "http_clients": [{"tag": "direct-http"}],
  "route": {
    "rule_set": [
      {"type": "remote", "tag": "explicit", "url": "https://example.com/explicit.srs"}
    ]
  }
}
EOF
if compat_sing_box_issue_report "$tmp_dir/explicit-http-client.json" | grep -q '^implicit_rule_set_http_client'; then
    fail "explicit top-level HTTP client was reported as implicit"
fi

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
grep -q '推荐稳定版 1.14.2' <<< "$doctor_output" || fail "doctor did not recommend sing-box 1.14.2"

doctor_output=""
is_core_ver=1.14.2
runtime_doctor_sing_box_version || fail "recommended sing-box stable version failed doctor"
grep -q '推荐稳定版基线 1.14.2' <<< "$doctor_output" || fail "doctor did not accept sing-box 1.14.2"

doctor_output=""
is_core_ver=1.15.0-alpha.1
if runtime_doctor_sing_box_version; then
    fail "sing-box prerelease passed the stable-version doctor check"
fi
grep -q '预发布版' <<< "$doctor_output" || fail "doctor did not warn about a sing-box prerelease"

mkdir -p "$tmp_dir/caddy/sites" "$tmp_dir/caddy/managed"
cat > "$tmp_dir/caddy/Caddyfile" << 'EOF'
import sites/*.conf
EOF
cat > "$tmp_dir/caddy/sites/risk.conf" << 'EOF'
example.com {
    forward_auth localhost:9091
    reverse_proxy localhost:8080
}
EOF
is_caddy=1
is_caddy_ver=v2.11.4
is_caddy_bin="$tmp_dir/missing-caddy"
is_caddy_dir="$tmp_dir/caddy"
is_caddyfile="$tmp_dir/caddy/Caddyfile"
is_caddy_conf="$tmp_dir/caddy/managed"
doctor_output=""
msg() { doctor_output+="MSG:$*"$'\n'; }
if runtime_doctor_caddy_security; then
    fail "Caddy forward_auth/reverse_proxy risk passed doctor"
fi
grep -q 'risk.conf' <<< "$doctor_output" || fail "doctor did not list the risky Caddy config"
grep -q '2.11.5' <<< "$doctor_output" || fail "doctor did not mention the patched Caddy target"

doctor_output=""
is_caddy_ver=v2.10.2
if runtime_doctor_caddy_security; then
    fail "old Caddy version unexpectedly passed the recommended baseline"
fi
grep -q '低于已复核稳定基线 2.11.4' <<< "$doctor_output" || fail "doctor did not report the Caddy stable baseline"

cloudflared() { printf '%s\n' 'cloudflared version 2026.9.3'; }
systemctl() {
    case $1 in
        list-unit-files) printf '%s\n' 'cftunnel-443.service enabled' ;;
        show) printf '%s\n' '4' ;;
    esac
}
journalctl() {
    printf '%s\n' 'failed with CRYPTO_ERROR 0x178 (remote): tls: no application protocol'
}
doctor_output=""
if runtime_doctor_cloudflared_runtime; then
    fail "cloudflared restart/QUIC failure passed doctor"
fi
grep -q '已自动重启 4 次' <<< "$doctor_output" || fail "doctor did not report cloudflared restart count"
grep -q '未回退 HTTP/2' <<< "$doctor_output" || fail "doctor did not report cloudflared QUIC fallback failure"

systemctl() {
    case $1 in
        list-unit-files) printf '%s\n' 'cftunnel-443.service enabled' ;;
        show) printf '%s\n' '0' ;;
    esac
}
journalctl() { :; }
doctor_output=""
runtime_doctor_cloudflared_runtime || fail "healthy cloudflared service failed doctor"
grep -q '未发现频繁重启或已知 QUIC 错误特征' <<< "$doctor_output" || fail "doctor did not report healthy cloudflared services"

echo "[upstream-compat] ok"
