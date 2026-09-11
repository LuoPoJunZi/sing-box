#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/node/create.sh
. src/core/node/add/prepare.sh
. src/core/node/transaction.sh
. src/core/domain/store.sh
. src/core/domain/pool.sh
. src/core/domain/health.sh
. src/core/domain/pick.sh
. src/lib/net.sh
. src/core/admin/dispatch.sh
. src/caddy.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
msg() { :; }
warn() { :; }
unexpected() {
    echo "[dry-run-writes] unexpected mutation: $*" >&2
    touch "$tmp_dir/mutation"
    return 1
}
node_build_main_config() { unexpected build-main; }
snapshot_ensure() { unexpected snapshot; }
manage() { unexpected manage; }
download() { unexpected download; }
install_service() { unexpected service; }
firewall_allow() { unexpected firewall; }
_try_enable_bbr() { unexpected bbr; }
domain() { unexpected domain-command; }
is_core_bin=unexpected
is_dry_run=1
is_install_caddy=1
is_config_json="$tmp_dir/missing/config.json"
is_conf_dir="$tmp_dir/missing/conf"
write_create config.json
write_create caddy
caddy_config new
write_add_install_caddy_if_needed
node_commit_config main '{}'
is_test() { :; }
# get_port uses legacy arithmetic under callers without errexit.
get_port || exit 1
[[ $tmp_port ]]
for command in bbr bin run format import dns domain sub mystery; do
    admin_dispatch_command "$command" ignored
done
[[ ! -e "$tmp_dir/missing" && ! -e "$tmp_dir/mutation" ]]

# Select an SNI using real storage/cache helpers, without external network access.
domain_weighted_pick() { printf 'example.com\n'; }
domain_probe() { return 0; }
is_random_servername=example.com
for mode in is_dry_run is_gen is_test_json; do
    unset is_dry_run is_gen is_test_json
    printf -v "$mode" '%s' 1
    is_sh_dir="$tmp_dir/absent"
    [[ $(domain_pick_for_reality global) == example.com ]]
    [[ ! -e "$is_sh_dir" ]]
    is_sh_dir="$tmp_dir/existing"
    mkdir -p "$is_sh_dir"
    for file in domain_custom.list domain_disabled.list domain_health.cache domain_recent.list; do
        printf 'sentinel\n' > "$is_sh_dir/$file"
    done
    before=$(sha256sum "$is_sh_dir"/*)
    [[ $(domain_pick_for_reality global) == example.com ]]
    [[ $(sha256sum "$is_sh_dir"/*) == "$before" ]]
    get_port || exit 1
done
[[ ! -e "$tmp_dir/mutation" ]]

# The SS2022 password probe must not write a temporary config in preview mode.
(
    is_sh_dir=$ROOT_DIR
    . src/core/node/add.sh
    is_dry_run=1
    unset is_gen is_test_json
    is_new_protocol=Shadowsocks
    ss_method=2022-blake3-aes-128-gcm
    ss_password=placeholder
    write_add_resolve_protocol() { :; }
    write_add_prepare_protocol_args() { :; }
    write_add_apply_cli_args() { :; }
    write_add_prompt_remark() { :; }
    create() {
        [[ ! ${is_test_json:-} ]] || unexpected ss2022-probe
        printf 'preview\n' >> "$tmp_dir/create-calls"
    }
    info() { unexpected info; }
    write_add
    [[ $(cat "$tmp_dir/create-calls") == preview ]]
    [[ ! -e "$tmp_dir/mutation" ]]
)
echo "[dry-run-writes] ok: rebuild, Caddy, firewall, dispatch, SNI stores, SS2022"
