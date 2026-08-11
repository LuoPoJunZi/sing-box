#!/bin/bash

admin_menu_run() {
    admin_dispatch_command "$@"
}

admin_menu_run_service_action() {
    case $1 in
        1) admin_menu_run start ;;
        2) admin_menu_run stop ;;
        3) admin_menu_run restart ;;
    esac
}

admin_menu_run_update_action() {
    local index=$1 target=""

    if [[ $index =~ ^[0-9]+$ && $index -ge 1 && $index -le ${#admin_menu_update_targets[@]} ]]; then
        target=${admin_menu_update_targets[$((index - 1))]}
        admin_menu_run update "$target"
    fi
}

admin_menu_ask_advanced_action() {
    msg "\n请选择进阶工具:\n"
    msg "(1)  节点订阅(Sub)"
    msg "(2)  查看全部节点"
    msg "(3)  启用BBR"
    msg "(4)  查看日志"
    msg "(5)  测试运行"
    msg "(6)  重装脚本"
    msg "(7)  设置DNS"
    msg "(8)  手动更新"
    msg "(9)  系统诊断(doctor)"
    msg "(10) 查看快照列表"
    msg "(11) 手动创建快照"
    msg "(12) 回滚快照"
    msg "(13) 查看安装清单"

    while :; do
        echo -ne "\n➡️ 请输入对应的数字 $(ui_key "(输入 0 返回主面板)"): "
        read REPLY
        if [[ "$REPLY" == "0" ]]; then
            echo
            ui_cancel_msg
            sleep 0.5
            is_main_menu
            exit 0
        fi
        if [[ "$REPLY" =~ ^([1-9]|1[0-3])$ ]]; then
            break
        fi
        msg "输入${is_err}"
    done
}

admin_menu_run_advanced_action() {
    case $1 in
        1) admin_menu_run sub ;;
        2) admin_menu_run all ;;
        3) admin_menu_run bbr ;;
        4) admin_menu_run log ;;
        5) admin_menu_run test ;;
        6) admin_menu_run reinstall ;;
        7) admin_menu_run dns ;;
        8)
            is_tmp_list=("更新$is_core_name" "更新脚本")
            admin_menu_update_targets=(core sh)
            if [[ $is_caddy ]]; then
                is_tmp_list+=("更新Caddy")
                admin_menu_update_targets+=(caddy)
            fi
            if command -v cloudflared > /dev/null 2>&1; then
                is_tmp_list+=("更新cloudflared")
                admin_menu_update_targets+=(cloudflared)
            fi
            ask list is_do_update "" "\n请选择手动更新:"
            admin_menu_run_update_action "$REPLY"
            ;;
        9) admin_menu_run doctor ;;
        10) admin_menu_run backup list ;;
        11) admin_menu_run backup create manual-menu ;;
        12) admin_menu_run rollback ;;
        13) admin_menu_run manifest ;;
    esac
}

admin_menu_run_main_action() {
    case $1 in
        1) admin_menu_run add ;;
        2) admin_menu_run change ;;
        3) admin_menu_run info ;;
        4) admin_menu_run del ;;
        5)
            ask list is_do_manage "启动 停止 重启" "" "\n请选择系统服务状态:"
            admin_menu_run_service_action "$REPLY"
            msg "\n管理状态执行: $(_green $is_do_manage)\n"
            ;;
        6) admin_menu_run cron ;;
        7) admin_menu_run uninstall ;;
        8)
            msg
            admin_menu_run help
            ;;
        9)
            admin_menu_ask_advanced_action
            admin_menu_run_advanced_action "$REPLY"
            ;;
        10) admin_menu_run about ;;
    esac
}
