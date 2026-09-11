#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/node/transaction.sh
. src/core/node/create.sh
. src/core/node/build.sh
. src/core/node/change/actions.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
is_conf_dir="$tmp_dir/conf"
is_config_json="$tmp_dir/config.json"
mkdir "$is_conf_dir"
printf '{}\n' > "$is_config_json"
printf '{"inbounds":[{"tag":"old"}]}\n' > "$is_conf_dir/old node.json"
printf '{"inbounds":[{"tag":"peer"}]}\n' > "$is_conf_dir/peer.json"
cp "$is_conf_dir/old node.json" "$tmp_dir/original"
msg() { :; }
warn() { :; }
err() { return 1; }
fail() {
    echo "[config-transaction] $*" >&2
    exit 1
}
fake_core() {
    [[ $1 == check && $2 == -c && $4 == -C ]] || return 1
    [[ -f $3 && -f $5/peer.json ]] || return 1
    [[ $(find "$5" -name '*.json' | wc -l) == 2 ]] || return 1
    [[ ! ${reject_core:-} ]]
}
is_core_bin=fake_core
is_core=sing-box
# Rebuild still repairs malformed main JSON; valid NTP preferences survive.
printf '{"ntp":{"enabled":true}}\n' > "$is_config_json"
node_build_main_config | jq -e '.ntp.enabled == true' > /dev/null
printf 'broken JSON\n' > "$is_config_json"
node_build_main_config | jq -e '.dns == {} and (.ntp == null)' > /dev/null
printf '{}\n' > "$is_config_json"
candidate='{"inbounds":[{"tag":"replacement"}]}'
assert_original() {
    cmp "$tmp_dir/original" "$is_conf_dir/old node.json"
    [[ ! -e "$is_conf_dir/new node.json" ]]
    [[ ! -e ${is_config_json}.write-lock ]]
}
reject_core=1
if node_commit_config node "$candidate" "new node.json" "old node.json"; then fail "accepted rejected core"; fi
assert_original
unset reject_core
if node_commit_config node 'not JSON' "new node.json" "old node.json" 2> /dev/null; then fail "accepted invalid JSON"; fi
assert_original
if node_commit_config node "$candidate" "../outside.json" "old node.json"; then fail "accepted traversal"; fi
if node_commit_config node "$candidate" peer.json "old node.json"; then fail "overwrote peer"; fi
cp() { return 1; }
if node_commit_config node "$candidate" "new node.json" "old node.json"; then fail "ignored backup failure"; fi
unset -f cp
assert_original
mv() {
    if [[ $* == *'/conf/new node.json'* && $* != *target.before* ]]; then return 1; fi
    command mv "$@"
}
if node_commit_config node "$candidate" "new node.json" "old node.json"; then fail "ignored rename failure"; fi
unset -f mv
assert_original
rm() {
    if [[ ${!#} == "$is_conf_dir/old node.json" ]]; then return 1; fi
    command rm "$@"
}
if node_commit_config node "$candidate" "new node.json" "old node.json"; then fail "ignored removal failure"; fi
unset -f rm
assert_original
node_commit_config node "$candidate" "new node.json" "old node.json"
[[ ! -e "$is_conf_dir/old node.json" ]]
jq -e '.inbounds[0].tag == "replacement"' "$is_conf_dir/new node.json" > /dev/null
node_commit_config node '{"inbounds":[{"tag":"updated"}]}' "new node.json" "new node.json"
jq -e '.inbounds[0].tag == "updated"' "$is_conf_dir/new node.json" > /dev/null
mkdir "${is_config_json}.write-lock"
if node_commit_config main '{}'; then fail "ignored writer lock"; fi
rmdir "${is_config_json}.write-lock"
node_commit_config main '{"dns":{}}'
jq -e '.dns == {}' "$is_config_json" > /dev/null

# Exercise the production caller, not just the commit helper.
get() { :; }
node_prepare_protocol() { :; }
node_build_config() { printf '%s\n' "$candidate"; }
snapshot_ensure() { [[ ! ${reject_snapshot:-} ]]; }
write_cleanup_replaced_node() { printf cleanup >> "$tmp_dir/effects"; }
write_add_install_caddy_if_needed() { printf caddy >> "$tmp_dir/effects"; }
manage() { printf restart >> "$tmp_dir/effects"; }
is_new_protocol=Socks
custom_remark="test"
port=12345
net=socks
is_config_file="new node.json"
reject_core=1
if write_create server Socks; then fail "caller ignored validation failure"; fi
[[ ! -e "$tmp_dir/effects" ]]
unset reject_core
reject_snapshot=1
if write_create server Socks; then fail "caller ignored snapshot failure"; fi
[[ ! -e "$tmp_dir/effects" ]]
unset reject_snapshot
write_create server Socks
wait
[[ ! -e "$is_conf_dir/new node.json" && -f "$is_conf_dir/Socks-test-12345.json" ]]
[[ $(cat "$tmp_dir/effects") == cleanupcaddyrestart ]]

# Manual Reality edits preserve unrelated JSON and do not restart on rejection.
is_config_file="Socks-test-12345.json"
is_reality=1
private=$(printf 'a%.0s' {1..43})
public=$(printf 'b%.0s' {1..43})
printf '{"inbounds":[{"tls":{"reality":{"private_key":"before","short_id":["abcd"]}}}],"outbounds":[{"type":"direct","tag":"keep"},{"type":"direct","tag":"public_key_old"}]}' > "$is_conf_dir/$is_config_file"
info() { :; }
reject_core=1
if write_change_key_action unused unused "$private" "$public"; then fail "key edit ignored core failure"; fi
jq -e '.inbounds[0].tls.reality.private_key == "before"' "$is_conf_dir/$is_config_file" > /dev/null
[[ $(cat "$tmp_dir/effects") == cleanupcaddyrestart ]]
unset reject_core
write_change_key_action unused unused "$private" "$public"
wait
jq -e --arg private "$private" --arg public "$public" '.inbounds[0].tls.reality.private_key == $private and .inbounds[0].tls.reality.short_id == ["abcd"] and [.outbounds[].tag] == ["keep", ("public_key_" + $public)]' "$is_conf_dir/$is_config_file" > /dev/null
if write_change_key_action unused unused 'bad"key' "$public"; then fail "accepted invalid key"; fi
[[ ! -e ${is_config_json}.write-lock ]]
[[ -z $(find "$tmp_dir" -name '.config-txn.*' -print) ]]
echo "[config-transaction] ok: rejection, replacement, rollback, callers, key edits"
