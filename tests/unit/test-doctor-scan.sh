#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
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
echo "[doctor-scan] ok"
