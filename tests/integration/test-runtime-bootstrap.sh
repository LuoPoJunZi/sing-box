#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/runtime/bootstrap.sh
. src/core/admin/maintenance.sh
. src/core/runtime/service.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
is_tls_key="$tmp_dir/tls.key"
is_tls_cer="$tmp_dir/tls.cer"
is_core_bin=fake_core
msg() { :; }
warn() { :; }
fake_core() {
    printf 'called\n' >> "$tmp_dir/calls"
    [[ ${fake_fail:-} ]] && return 1
    printf '%s\n' '-----BEGIN PRIVATE KEY-----' key '-----END PRIVATE KEY-----'
    printf '%s\n' '-----BEGIN CERTIFICATE-----' cert '-----END CERTIFICATE-----'
}
is_dry_run=1
runtime_ensure_tls
admin_reinstall
admin_install_caddy
runtime_test_run
[[ ! -e $tmp_dir/calls && ! -e $is_tls_key ]]
unset is_dry_run
fake_fail=1
if runtime_ensure_tls; then exit 1; fi
[[ ! -e $is_tls_key && ! -e $is_tls_cer && ! -d $tmp_dir/.tls.lock ]]
unset fake_fail
runtime_ensure_tls
[[ -s $is_tls_key && -s $is_tls_cer ]]
before=$(sha256sum "$is_tls_key" "$is_tls_cer")
runtime_ensure_tls
[[ $(sha256sum "$is_tls_key" "$is_tls_cer") == "$before" ]]
mv "$is_tls_cer" "$tmp_dir/saved.cer"
if runtime_ensure_tls; then exit 1; fi
[[ -s $is_tls_key && ! -e $is_tls_cer ]]
echo "[runtime-bootstrap] ok"
