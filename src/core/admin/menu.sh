#!/bin/bash

admin_is_main_menu() {
    is_main_start=1
    while :; do
        clear
        ui_hr
        ui_title "     sing-box 管理面板 $is_sh_ver  |  快捷启动: sb"
        ui_hr

        local caddy_show=""
        if [[ $is_caddy ]]; then
            caddy_show=" | Caddy: ${is_caddy_status}"
        fi
        echo -e "  Core: ${is_core_ver} (${is_core_status})${caddy_show} | Nodes: $(list_conf_json_names '.json$' | wc -l)"
        ui_divider

        echo -e "  $(ui_section 节点管理)"
        echo -e "    $(ui_option_num 1) 添加配置      $(ui_option_num 2) 更改配置"
        echo -e "    $(ui_option_num 3) 查看节点      $(ui_option_num 4) 删除配置\n"

        echo -e "  $(ui_section 系统控制)"
        echo -e "    $(ui_option_num 5) 启动/停止     $(ui_option_num 6) 自动维护"
        echo -e "    $(ui_error "(7) 完全卸载")      $(ui_option_num 8) 帮助文档\n"

        echo -e "  $(ui_section 高级工具)"
        echo -e "    $(ui_option_num 9) 进阶选项     $(ui_option_num 10) 关于脚本"
        echo -e "    $(ui_option_num 0) 退出"
        ui_divider

        echo -ne "\n请输入数字 [$(ui_range 0-10)]: "
        read REPLY

        if [[ ! $REPLY ]]; then continue; fi
        if [[ "$REPLY" == "0" ]]; then exit; fi
        if [[ "$REPLY" =~ ^([1-9]|10)$ ]]; then break; fi
        ui_error "输入错误, 请输入 0-10 之间的数字"
        sleep 1
    done

    admin_menu_run_main_action "$REPLY"
}
