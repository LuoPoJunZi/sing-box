#!/bin/bash

admin_main() {
    if [[ $1 == 'dry-run' || $1 == '--dry-run' || $1 == 'drun' ]]; then
        is_dry_run=1
        shift
        if [[ ! $1 ]]; then
            err "请使用: sb dry-run <command> [args...]"
        fi
        msg "\n已启用 DRY-RUN 模式，本次不会执行写入或服务变更.\n"
    fi

    admin_dispatch_command "$@"
}

admin_dispatch_command() {
    case $1 in
        a | add | gen | no-auto-tls)
            if [[ $1 == 'gen' ]]; then is_gen=1; fi
            if [[ $1 == 'no-auto-tls' ]]; then is_no_auto_tls=1; fi
            add "${@:2}"
            ;;
        bin | pbk | check | completion | format | generate | geoip | geosite | merge | rule-set | run | tools)
            is_run_command=$1
            if [[ $1 == 'bin' ]]; then
                "$is_core_bin" "${@:2}"
            elif [[ $is_run_command == 'pbk' ]]; then
                "$is_core_bin" generate reality-keypair "${@:2}"
            else
                "$is_core_bin" "$is_run_command" "${@:2}"
            fi
            ;;
        bbr) _try_enable_bbr ;;
        c | config | change) change "${@:2}" ;;
        d | del | rm) del "$2" ;;
        dd | ddel | fix | fix-all)
            case $1 in
                fix)
                    if [[ $2 ]]; then change "$2" full; else is_change_id=full && change; fi
                    return
                    ;;
                fix-all)
                    is_dont_auto_exit=1
                    msg
                    local conf_files=()
                    mapfile -t conf_files < <(list_conf_json_names '.json$')
                    for v in "${conf_files[@]}"; do
                        msg "fix: $v"
                        change "$v" full
                    done
                    _green "\nfix 完成.\n"
                    ;;
                *)
                    is_dont_auto_exit=1
                    if [[ ! $2 ]]; then
                        err "无法找到需要删除的参数"
                    else
                        for v in "${@:2}"; do
                            del "$v"
                        done
                    fi
                    ;;
            esac
            is_dont_auto_exit=
            manage restart &
            if [[ $is_del_host ]]; then manage restart caddy & fi
            ;;
        dns) dns_set "${@:2}" ;;
        domain | domains) domain "${@:2}" ;;
        doctor | diag) doctor ;;
        manifest | mf) manifest "$2" ;;
        backup)
            case "${2:-list}" in
                list | ls) backup_list ;;
                create)
                    unset is_snapshot_id
                    snapshot_ensure "${3:-manual}"
                    ;;
                *) err "无法识别 backup 参数, 请使用: sb backup [list|create [reason]]" ;;
            esac
            ;;
        rollback | restore) rollback "${2:-}" ;;
        cron) cron_task ;;
        sub) gen_sub ;;
        all) show_all_nodes ;;
        debug)
            is_debug=1
            get info "$2"
            warn "如果需要复制; 请把 *uuid, *password, *host, *key 的值改写, 以避免泄露."
            ;;
        fix-config.json) create config.json ;;
        fix-caddyfile)
            if [[ $is_caddy ]]; then
                load caddy.sh
                caddy_config new
                manage restart caddy &
                _green "\nfix 完成.\n"
            else
                err "无法执行此操作"
            fi
            ;;
        i | info) info "$2" ;;
        ip)
            get_ip
            msg "$ip"
            ;;
        in | import) load import.sh ;;
        log) log_set "$2" ;;
        url | qr) url_qr "$@" ;;
        un | uninstall) uninstall ;;
        u | up | update | U | update.sh)
            is_update_name="${2:-}"
            is_update_ver="${3:-}"
            if [[ ! $is_update_name ]]; then is_update_name=core; fi
            if [[ $1 == 'U' || $1 == 'update.sh' ]]; then
                is_update_name="sh"
                is_update_ver=
            fi
            update "$is_update_name" "$is_update_ver"
            ;;
        ssss | ss2022) get "$@" ;;
        s | status)
            msg "\n$is_core_name $is_core_ver: $is_core_status\n"
            if [[ $is_caddy ]]; then msg "Caddy $is_caddy_ver: $is_caddy_status\n"; fi
            ;;
        start | stop | r | restart)
            if [[ $2 && $2 != 'caddy' ]]; then err "无法识别 ($2), 请使用: $is_core $1 [caddy]"; fi
            manage "$1" "$2" &
            ;;
        t | test) get test-run ;;
        reinstall) get "$1" ;;
        get-port)
            get_port
            msg $tmp_port
            ;;
        main) is_main_menu ;;
        v | ver | version)
            if [[ $is_caddy_ver ]]; then is_caddy_ver="/ $(_blue Caddy $is_caddy_ver)"; fi
            msg "\n$(_green $is_core_name $is_core_ver) / $(_cyan LuoPo Script $is_sh_ver) $is_caddy_ver\n"
            ;;
        h | help | --help)
            load help.sh
            show_help "${@:2}"
            ;;
        about)
            load help.sh
            about
            ;;
        *)
            is_try_change=1
            change test "$1"
            if [[ $is_change_id ]]; then
                unset is_try_change
                if [[ $2 ]]; then change "$2" "$1" "${@:3}"; else change; fi
            else
                err "无法识别 ($1), 获取帮助请使用: sb help"
            fi
            ;;
    esac
}
