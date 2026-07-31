#!/bin/bash

admin_update() {
    case $1 in
        1 | core | "$is_core")
            is_update_name=core
            is_show_name="$is_core_name"
            is_run_ver=v${is_core_ver##* }
            ;;
        2 | sh)
            is_update_name="sh"
            is_show_name="$is_core_name 脚本"
            is_run_ver="$is_sh_ver"
            ;;
        3 | caddy)
            if [[ ! $is_caddy ]]; then err "不支持更新 Caddy."; fi
            is_update_name=caddy
            is_show_name="Caddy"
            is_run_ver="$is_caddy_ver"
            ;;
        *)
            err "无法识别 ($1), 请使用: $is_core update [core | sh | caddy] [ver]"
            ;;
    esac

    if [[ $2 ]]; then is_new_ver=v${2#v}; fi

    if [[ $is_run_ver == "$is_new_ver" ]]; then
        msg "\n自定义版本和当前 $is_show_name 版本一样, 无需更新.\n"
        exit
    fi

    if [[ $is_new_ver ]]; then
        msg "\n使用自定义版本更新 $is_show_name: $(_green $is_new_ver)\n"
    else
        get_latest_version $is_update_name
        if [[ $is_run_ver == "$latest_ver" ]]; then
            msg "\n$is_show_name 当前已经是最新版本了.\n"
            exit
        fi
        msg "\n发现 $is_show_name 新版本: $(_green $latest_ver)\n"
        is_new_ver=$latest_ver
    fi

    download "$is_update_name" "$is_new_ver"
    msg "更新成功, 当前 $is_show_name 版本: $(_green $is_new_ver)\n"

    if [[ $is_update_name != 'sh' ]]; then
        manage restart "$is_update_name" &
    fi
}
