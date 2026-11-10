#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/lib/version.sh
. src/lib/tunnel.sh
. src/core/utils/download.sh
. src/core/admin/update.sh
tmp_dir=$(mktemp -d)
guard_test_dir=$tmp_dir
trap 'rm -rf -- "$tmp_dir"' EXIT
fail() {
    echo "[upstream-install-guards] $*" >&2
    exit 1
}
msg() { :; }
err() { return 1; }
_green() { printf '%s' "$*"; }
github_release_tag_is_safe() { return 0; }
download_stage_cleanup() { :; }

# Refuse the explicitly regressed Caddy before staging or host mutations.
if download_stage_component caddy v2.11.6 "$tmp_dir/stage"; then fail 'staging accepted Caddy 2.11.6'; fi
[[ ! -e $tmp_dir/stage ]] || fail 'blocked staging created files'
if download caddy v2.11.6; then fail 'fresh install accepted Caddy 2.11.6'; fi

# Mismatched/regressed candidates must never reach replacement or systemctl.
is_new_ver=v2.11.9
download_stage_dir="$tmp_dir/stage"
download_stage_root="$tmp_dir/content"
mkdir "$download_stage_root"
admin_update_replace_binary() { fail 'unsafe candidate reached replacement'; }
systemctl() { fail 'unsafe candidate reached systemctl'; }
for reported in v2.11.4 v2.11.6; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$reported" > "$download_stage_root/caddy"
    chmod +x "$download_stage_root/caddy"
    if admin_update_caddy; then fail "mismatched Caddy $reported was accepted"; fi
done
is_new_ver=v2.11.6
if admin_update_caddy; then fail 'matching regressed Caddy was accepted'; fi
is_new_ver=v2.11.9
printf '#!/bin/sh\nprintf "v2.11.9\\n"\nexit 1\n' > "$download_stage_root/caddy"
if admin_update_caddy; then fail 'failed Caddy version command was accepted'; fi

# Exercise the allowed update and health rollback with file/service mocks.
mkdir "$download_stage_dir"
is_caddy_bin="$guard_test_dir/installed-caddy"
is_caddyfile="$guard_test_dir/missing-Caddyfile"
is_new_ver=v2.11.9
printf '%s\n' old-caddy > "$is_caddy_bin"
# Stricter parsing in a new Caddy must reject custom configs before replacement
# or a service restart. No actual Caddy or systemctl is invoked by this test.
is_caddyfile="$guard_test_dir/custom-Caddyfile"
printf '%s\n' incompatible-custom-config > "$is_caddyfile"
printf '#!/bin/sh\ncase "$1" in version) printf "v2.11.9\\n" ;; validate) exit 1 ;; *) exit 2 ;; esac\n' > "$download_stage_root/caddy"
chmod +x "$download_stage_root/caddy"
if admin_update_caddy; then fail 'invalid custom Caddyfile reached replacement'; fi
grep -q old-caddy "$is_caddy_bin" || fail 'invalid config replaced installed Caddy'
is_caddyfile="$guard_test_dir/missing-Caddyfile"
printf '#!/bin/sh\nprintf "v2.11.9\\n"\n' > "$download_stage_root/caddy"
chmod +x "$download_stage_root/caddy"
admin_update_replace_binary() { command cp -- "$1" "$2"; }
systemctl() { printf '%s\n' "$*" >> "$guard_test_dir/service-events"; }
health_ok=0
admin_update_service_healthy() { [[ $health_ok -eq 1 ]]; }
if admin_update_caddy; then fail 'unhealthy Caddy update succeeded'; fi
grep -q old-caddy "$is_caddy_bin" || fail 'Caddy rollback did not restore old binary'
health_ok=1
admin_update_caddy || fail 'matching healthy Caddy update failed'
grep -q v2.11.9 "$is_caddy_bin" || fail 'matching Caddy candidate was not retained'

admin_update_replace_binary() { fail 'unsafe cloudflared reached binary replacement'; }
is_new_ver=2026.10.7
for reported in 2026.10.1 2026.10.3 2026.10.4 unknown; do
    printf '#!/bin/sh\nprintf "cloudflared version %s\\n"\n' "$reported" > "$download_stage_root/cloudflared"
    chmod +x "$download_stage_root/cloudflared"
    if admin_update_cloudflared; then fail 'unsafe/mismatched cloudflared update candidate accepted'; fi
done

# Mock downloads and install to a private log, never /usr/local/bin.
requested=2026.10.7
reported=2026.10.7
fetch_ok=1
download_ok=1
install_ok=1
candidate_exit=0
github_release_fetch() { [[ $fetch_ok -eq 1 ]]; }
github_release_tag() { printf '%s\n' "$requested"; }
download_verified_release_asset() {
    [[ $download_ok -eq 1 ]] || return 1
    printf '%s\n' download >> "$guard_test_dir/events"
    printf '#!/bin/sh\nprintf "cloudflared version %s\\n"\nexit %s\n' "$reported" "$candidate_exit" > "$4"
}
install() {
    printf '%s\n' install >> "$guard_test_dir/events"
    [[ $install_ok -eq 1 ]]
}
managed_record() { printf '%s\n' manifest >> "$guard_test_dir/events"; }
command() {
    if [[ $1 == -v && $2 == cloudflared ]]; then return 1; fi
    builtin command "$@"
}
for requested in 2026.8.0 v2026.8.1 2026.10.1 2026.10.2 2026.10.3 2026.10.7-rc.1; do
    if download_stage_component cloudflared "$requested" "$tmp_dir/unsafe-stage"; then fail 'unsafe cloudflared reached staging'; fi
    [[ ! -e $tmp_dir/unsafe-stage ]] || fail 'security rejection created staging files'
    if install_cloudflared; then fail "blocked cloudflared $requested installed"; fi
    [[ ! -e $tmp_dir/events ]] || fail 'blocked cloudflared was downloaded'
done
requested=2026.10.7
for reported in 2026.8.1 2026.9.3 ''; do
    : > "$tmp_dir/events"
    if install_cloudflared; then fail "mismatched cloudflared $reported installed"; fi
    if grep -q 'install\|manifest' "$tmp_dir/events"; then fail 'unsafe cloudflared reached install'; fi
done
reported=2026.10.7
candidate_exit=1
: > "$tmp_dir/events"
if install_cloudflared; then fail 'failed cloudflared version command was accepted'; fi
if grep -q 'install\|manifest' "$tmp_dir/events"; then fail 'failed candidate reached install'; fi
candidate_exit=0
fetch_ok=0
: > "$tmp_dir/events"
if install_cloudflared; then fail 'metadata failure was ignored'; fi
[[ ! -s $tmp_dir/events ]] || fail 'metadata failure reached download/install'
fetch_ok=1
download_ok=0
if install_cloudflared; then fail 'download/checksum failure was ignored'; fi
[[ ! -s $tmp_dir/events ]] || fail 'download failure reached install'
download_ok=1
install_ok=0
if install_cloudflared; then fail 'install failure was ignored'; fi
if grep -q manifest "$tmp_dir/events"; then fail 'failed install was recorded as successful'; fi
install_ok=1
: > "$tmp_dir/events"
install_cloudflared || fail 'verified matching cloudflared rejected'
grep -q install "$tmp_dir/events" || fail 'matching cloudflared did not install'
grep -q manifest "$tmp_dir/events" || fail 'matching cloudflared was not tracked'

# Existing binaries must not bypass the safety floor or cause service changes.
command() { builtin command "$@"; }
cloudflared() {
    printf 'cloudflared version %s\n' "$reported"
    return "$candidate_exit"
}
for reported in 2026.8.2 2026.10.1 2026.10.3 unknown; do
    : > "$tmp_dir/events"
    if install_cloudflared; then fail 'unsafe existing cloudflared was reused'; fi
    [[ ! -s $tmp_dir/events ]] || fail 'unsafe existing binary caused download/install'
done
reported=2026.10.7
install_cloudflared || fail 'safe existing cloudflared was rejected'
[[ ! -s $tmp_dir/events ]] || fail 'safe existing binary was replaced'
candidate_exit=1
if install_cloudflared; then fail 'failed existing version command was accepted'; fi
echo '[upstream-install-guards] ok'
