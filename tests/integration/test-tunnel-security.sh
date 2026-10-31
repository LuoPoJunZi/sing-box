#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/lib/systemd.sh
. src/core/runtime/doctor/tunnel.sh

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
fail() {
    echo "[tunnel-security] $*" >&2
    exit 1
}
msg() { printf '%s\n' "$*"; }
_yellow() { printf '%s' "$*"; }
is_core_dir="$tmp_dir/core with spaces"
mkdir -p "$tmp_dir/units"
cftunnel_systemd_dir() { printf '%s\n' "$tmp_dir/units"; }
managed_record() { printf '%s|%s\n' "$1" "$2" >> "$tmp_dir/manifest"; }
start_ok=1
systemctl() {
    printf '%s\n' "$*" >> "$tmp_dir/events"
    [[ $1 != enable || $start_ok == 1 ]]
}
secret=fixture_token_NEVER_PRINT_123
output=$(create_cftunnel_service "$secret" 12345) || fail 'safe service creation failed'
token_file=$(cftunnel_token_path 12345)
unit_file="$tmp_dir/units/cftunnel-12345.service"
[[ $(< "$token_file") == "$secret" ]] || fail 'credential content incorrect'
[[ $output != *"$secret"* ]] || fail 'creation printed token'
if grep -Fq "$secret" "$unit_file" "$tmp_dir/events" "$tmp_dir/manifest"; then fail 'secret escaped credential file'; fi
grep -Fq -- '--metrics 127.0.0.1:0 run --token-file ' "$unit_file" || fail 'safe flags missing'
grep -Fq "file|$token_file" "$tmp_dir/manifest" || fail 'credential not tracked for uninstall'
grep -Fq "dir|${token_file%/*}" "$tmp_dir/manifest" || fail 'credential directory not tracked'
if [[ $(uname -s) == Linux ]]; then
    [[ $(stat -c %a "$token_file") == 600 && $(stat -c %a "${token_file%/*}") == 700 ]] || fail 'credential permissions unsafe'
fi
before=$(cksum "$tmp_dir/events")
if create_cftunnel_service different 12345 > /dev/null; then fail 'existing service overwritten'; fi
[[ $(< "$token_file") == "$secret" && $(cksum "$tmp_dir/events") == "$before" ]] || fail 'existing service mutated/restarted'
for invalid in 0 65536 01 ../outside '12345/../x'; do
    if create_cftunnel_service "$secret" "$invalid" > /dev/null; then fail 'invalid port accepted'; fi
done
if create_cftunnel_service $'token\nExecStart=unsafe' 12346 > /dev/null; then fail 'token injection accepted'; fi
[[ ! -e $tmp_dir/core\ with\ spaces/cftunnel/12346.token ]] || fail 'invalid token persisted'
start_ok=0
if create_cftunnel_service "$secret" 12347 > /dev/null; then fail 'start failure ignored'; fi
[[ ! -e $tmp_dir/units/cftunnel-12347.service && ! -e ${token_file%/*}/12347.token ]] || fail 'failed creation left credentials/unit'
remove_cftunnel_token 12345 || fail 'credential cleanup failed'
[[ ! -e $token_file ]] || fail 'credential left after deletion'

# Read-only diagnosis, including systemd output containing a fake credential.
# Do not let an assertion print the unit contents on failure.
runtime_doctor_ok() { printf 'OK:%s\n' "$*"; }
runtime_doctor_warn() { printf 'WARN:%s\n' "$*"; }
runtime_doctor_info() { printf 'INFO:%s\n' "$*"; }
unit_config="ExecStart=/usr/local/bin/cloudflared tunnel run --token $secret"
systemctl() {
    case $1 in
        list-unit-files) printf '%s\n' 'cftunnel-12345.service enabled' ;;
        cat) printf '%s\n' "$unit_config" ;;
        *) fail 'diagnosis invoked a mutating service command' ;;
    esac
}
if output=$(runtime_doctor_cloudflared_security); then fail 'legacy token service passed'; fi
[[ $output != *"$secret"* && $output == *'明文 token'* && $output == *'未在 ExecStart 显式限定回环'* ]] || fail 'legacy diagnostic incorrect/leaked secret'
unit_config="ExecStart=/usr/local/bin/cloudflared tunnel --metrics 0.0.0.0:20241 run --token-file /custom/token"
if output=$(runtime_doctor_cloudflared_security); then fail 'public metrics/custom credential passed'; fi
[[ $output == *'未在 ExecStart 显式限定回环'* && $output == *'需人工核查'* ]] || fail 'unverified config warning missing'
printf '%s\n' "$secret" > "$token_file"
unit_config=$(cftunnel_unit_content 12345 "$token_file")
stat() { printf '%s\n' "${mock_metadata:-600:0}"; }
output=$(runtime_doctor_cloudflared_security) || fail 'protected unit failed static diagnosis'
[[ $output != *"$secret"* && $output == *'不代表运行进程或公网隧道已验收'* ]] || fail 'diagnosis overstated scope'
protected_config=$unit_config
unit_config+=$'\nExecStart=\nExecStart=/usr/local/bin/cloudflared tunnel --metrics 0.0.0.0:20241 run --token-file /custom/token'
if output=$(runtime_doctor_cloudflared_security); then fail 'unsafe override hidden by safe base unit'; fi
[[ $output == *'含服务覆盖'* && $output != *"$secret"* ]] || fail 'override not diagnosed safely'
unit_config=$protected_config
for mock_metadata in 644:0 600:1000 unknown; do
    if output=$(runtime_doctor_cloudflared_security); then fail 'unsafe/unverified credential metadata passed'; fi
    [[ $output != *"$secret"* && $output == *'权限/属主'* ]] || fail 'unsafe metadata warning incorrect'
done
echo '[tunnel-security] ok: token files, cleanup, safe flags, failure propagation and redacted read-only diagnostics'
