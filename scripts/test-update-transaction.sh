#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[update-transaction] $*"
    exit 1
}

msg() { :; }
err() { return 1; }
_green() { printf '%s' "$*"; }
download_stage_cleanup() { :; }
legacy_dns=1
dns_config_uses_legacy_servers() { [[ $legacy_dns -eq 1 ]]; }
dns_build_modern_config() { printf '%s\n' '{"dns":{"servers":[{"type":"udp","server":"1.1.1.1"}]}}' > "$2"; }
json_check_core_config_with() { return 0; }
runtime_snapshot_ensure() { :; }
sleep() { :; }
pgrep() { return 0; }

health_ok=0
systemctl() {
    case $1 in
        restart) return 0 ;;
        is-active) [[ $health_ok -eq 1 ]] ;;
        *) return 0 ;;
    esac
}

. src/core/admin/update.sh

is_core=sing-box
is_core_name=sing-box
is_new_ver=v-test
is_conf_dir="$tmp_dir/conf"
is_config_json="$tmp_dir/config.json"
is_core_bin="$tmp_dir/bin/sing-box"
download_stage_dir="$tmp_dir/stage"
download_stage_root="$download_stage_dir/content"
mkdir -p "$is_conf_dir" "$(dirname "$is_core_bin")" "$download_stage_root"
printf '%s\n' '{"dns":{"servers":[{"address":"1.1.1.1"}]}}' > "$is_config_json"

cat > "$is_core_bin" << 'EOF'
#!/bin/sh
echo old-core
EOF
cat > "$download_stage_root/sing-box" << 'EOF'
#!/bin/sh
echo new-core
EOF
chmod +x "$is_core_bin" "$download_stage_root/sing-box"

if admin_update_core; then
    fail "unhealthy update unexpectedly succeeded"
fi
grep -q old-core "$is_core_bin" || fail "old core was not restored after failed health check"
grep -q '"address"' "$is_config_json" || fail "old config was not restored after failed health check"

health_ok=1
if ! admin_update_core; then
    fail "healthy update failed"
fi
grep -q new-core "$is_core_bin" || fail "new core was not retained after successful health check"
grep -q '"type"' "$is_config_json" || fail "migrated config was not retained after successful health check"

echo "[update-transaction] ok"
