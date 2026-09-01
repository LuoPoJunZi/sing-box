#!/bin/bash

# ==========================================
# sing-box Management Script Core Business Logic
# ==========================================

. "$is_sh_dir/src/core/env/defaults.sh"
. "$is_sh_dir/src/core/ui/output.sh"
. "$is_sh_dir/src/core/ui/prompt.sh"
. "$is_sh_dir/src/core/validate/input.sh"
. "$is_sh_dir/src/core/domain/store.sh"
. "$is_sh_dir/src/core/domain/health.sh"
. "$is_sh_dir/src/core/domain/pool.sh"
. "$is_sh_dir/src/core/domain/pick.sh"
. "$is_sh_dir/src/core/domain/cli.sh"
. "$is_sh_dir/src/core/runtime/snapshot.sh"
. "$is_sh_dir/src/core/runtime/rollback.sh"
. "$is_sh_dir/src/core/runtime/manifest.sh"
. "$is_sh_dir/src/core/runtime/doctor.sh"
. "$is_sh_dir/src/core/runtime/service.sh"
. "$is_sh_dir/src/core/runtime/cron.sh"
. "$is_sh_dir/src/core/query/protocol.sh"
. "$is_sh_dir/src/core/query/parse.sh"
. "$is_sh_dir/src/core/query/uri.sh"
. "$is_sh_dir/src/core/query/tls_pin.sh"
. "$is_sh_dir/src/core/query/info.sh"
. "$is_sh_dir/src/core/query/url.sh"
. "$is_sh_dir/src/core/node/create.sh"
. "$is_sh_dir/src/core/node/change.sh"
. "$is_sh_dir/src/core/node/delete.sh"
. "$is_sh_dir/src/core/node/add.sh"
. "$is_sh_dir/src/core/sub/generate.sh"
. "$is_sh_dir/src/core/admin/update.sh"
. "$is_sh_dir/src/core/admin/uninstall.sh"
. "$is_sh_dir/src/core/admin/menu_actions.sh"
. "$is_sh_dir/src/core/admin/menu.sh"
. "$is_sh_dir/src/core/admin/dispatch.sh"

msg() { ui_msg "$@"; }
msg_ul() { ui_msg_ul "$@"; }
pause() { ui_pause; }

show_list() { ui_show_list "$@"; }

is_test() { validate_is_test "$@"; }

is_port_used() { validate_is_port_used "$@"; }

create() { write_create "$@"; }

change() { write_change "$@"; }

del() { write_del "$@"; }

get() { query_get "$@"; }

info() { query_info "$@"; }

show_all_nodes() { query_show_all_nodes "$@"; }

gen_sub() { sub_gen_sub; }

add() { write_add "$@"; }

footer_msg() { ui_footer_msg; }

url_qr() { query_url_qr "$@"; }

manage() { runtime_manage "$@"; }

cron_task() { runtime_cron_task; }

snapshot_ensure() { runtime_snapshot_ensure "$@"; }

backup_list() { runtime_snapshot_list; }

rollback() { runtime_snapshot_restore "$@"; }

doctor() { runtime_doctor; }

manifest() { runtime_manifest_manage "$@"; }

domain() { domain_manage "$@"; }

update() { admin_update "$@"; }

uninstall() { admin_uninstall "$@"; }

is_main_menu() { admin_is_main_menu "$@"; }

main() { admin_main "$@"; }
