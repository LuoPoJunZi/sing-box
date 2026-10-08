#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/lib/version.sh
. src/core/runtime/doctor.sh
. src/core/utils/compat.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
is_conf_dir="$tmp_dir/conf"
is_config_json="$tmp_dir/main.json"
mkdir "$is_conf_dir"
msg() { printf '%s\n' "$*"; }
runtime_doctor_ok() { msg "$@"; }
runtime_doctor_warn() { msg "$@"; }
runtime_doctor_info() { msg "$@"; }
runtime_doctor_fail() { msg "$@"; }
printf '%s\n' '{"inbounds":[{"type":"vmess","users":[{"uuid":"test"}]}]}' > "$is_conf_dir/valid.json"
printf '%s\n' '{"inbounds":[{"type":"vmess","users":[{}]}]}' > "$is_conf_dir/missing.json"
printf '%s' '{broken' > "$is_conf_dir/broken.json"
output=$(runtime_doctor_client_compat || true)
[[ $output == *'1 个 JSON 配置无法解析'* ]]
[[ $output == *'1 个配置缺少 UUID、密码或加密方法'* ]]
[[ $output == *'broken.json'* && $output == *'missing.json'* ]]
printf '%s\n' '{"dns":{"servers":[{"address":"local"}]}}' > "$is_config_json"
output=$(runtime_doctor_sing_box_config_compat || true)
[[ $output == *'main.json'* && $output == *'待迁移配置'* ]]
# Report the reviewed upstream Reality bug only when Reality nodes exist.
printf '%s\n' '{"inbounds":[{"type":"vless","listen_port":31001,"users":[{"uuid":"test"}],"tls":{"reality":{"enabled":true,"private_key":"test","short_id":["0123abcd"],"handshake":{"server":"example.com"}},"server_name":"example.com"}}],"outbounds":[{"tag":"public_key_test"}]}' > "$is_conf_dir/reality.json"
runtime_doctor_port_listening() { return 0; }
is_core_ver=1.14.2
if runtime_doctor_reality > "$tmp_dir/output"; then
    echo '[doctor-scan] reported Reality risk did not return a warning' >&2
    exit 1
fi
output=$(< "$tmp_dir/output")
[[ $output == *'#4610'* && $output == *'尚未确认修复'* && $output == *'不重启服务'* ]]
is_core_ver=1.14.1
output=$(runtime_doctor_reality || true)
[[ $output != *'#4610'* ]]
rm "$is_conf_dir/reality.json"
is_core_ver=1.14.2
output=$(runtime_doctor_reality || true)
[[ $output == *'未发现配置'* && $output != *'#4610'* ]]
echo "[doctor-scan] ok"
