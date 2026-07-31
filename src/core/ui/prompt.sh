#!/bin/bash

ask() {
    case $1 in
        set_ss_method)
            is_tmp_list=("${ss_method_list[@]}")
            is_default_arg=$is_random_ss_method
            is_opt_msg="\n请选择加密方式:"
            is_opt_input_msg="➡️ 请选择 $(ui_key "(输入 0 返回主面板，默认 $is_default_arg)"): "
            is_ask_set=ss_method
            ;;
        set_protocol)
            ui_hr
            ui_title "                 请选择要添加的协议"
            ui_hr
            echo -e "  $(ui_section 基础协议)"
            echo -e "  $(ui_option_num 1) TUIC        $(ui_option_num 2) Trojan       $(ui_option_num 3) Hysteria2"
            echo -e "  $(ui_option_num 4) VMess-WS    $(ui_option_num 5) VMess-TCP    $(ui_option_num 6) VMess-HTTP"
            echo -e "  $(ui_option_num 7) VMess-QUIC  $(ui_option_num 8) Shadowsocks"
            echo
            echo -e "  $(ui_section "TLS 隧道")"
            echo -e "  $(ui_option_num 9)  VMess-H2   $(ui_option_num 10) VMess-WS    $(ui_option_num 11) VLESS-H2"
            echo -e "  $(ui_option_num 12) VLESS-WS   $(ui_option_num 13) Trojan-H2   $(ui_option_num 14) Trojan-WS"
            echo -e "  $(ui_option_num 15) VMess-HU   $(ui_option_num 16) VLESS-HU    $(ui_option_num 17) Trojan-HU\n"
            echo -e "  $(ui_section 强力抗封锁)"
            echo -e "  $(ui_option_num 18) VLESS-REALITY     $(ui_option_num 19) VLESS-HTTP2-REALITY"
            echo -e "  $(ui_option_num 20) AnyTLS\n"
            echo -e "  $(ui_section 隧道穿透)"
            echo -e "  $(ui_option_num 21) CFtunnel          $(ui_option_num 22) Socks\n"
            echo -e "  $(ui_section 取消操作)"
            echo -e "  $(ui_option_num 0) 返回主面板"
            ui_divider
            is_ask_set=is_new_protocol
            is_opt_input_msg="➡️ 请选择协议序号 [$(ui_range 0-22)]: "
            ;;
        set_change_list)
            is_tmp_list=()
            for v in "${is_can_change[@]}"; do
                is_tmp_list+=("${change_list[$v]}")
            done
            is_opt_msg="\n请选择更改:"
            is_ask_set=is_change_str
            is_opt_input_msg="➡️ 请输入对应的数字 $(ui_key "(输入 0 返回主面板)"): "
            ;;
        string)
            is_ask_set=$2
            is_opt_input_msg="${3/:/} $(ui_key "(输入 0 返回主面板)"): "
            ;;
        list)
            is_ask_set=$2
            if [[ -n ${3:-} ]]; then
                read -r -a is_tmp_list <<< "$3"
            elif [[ ${#is_tmp_list[@]} -eq 0 ]]; then
                unset is_tmp_list
            fi
            is_opt_msg=$4
            if [[ ! $is_opt_msg ]]; then
                is_opt_msg="\n请选择:"
            fi
            is_opt_input_msg=$5
            if [[ ! $is_opt_input_msg ]]; then
                is_opt_input_msg="➡️ 请输入对应的数字 $(ui_key "(输入 0 返回主面板)"): "
            else
                is_opt_input_msg="${is_opt_input_msg/:/} $(ui_key "(输入 0 返回主面板)"): "
            fi
            ;;
        get_config_file)
            is_tmp_list=("${is_all_json[@]}")
            is_opt_msg="\n请选择配置:"
            is_ask_set=is_config_file
            is_opt_input_msg="➡️ 请输入对应的数字 $(ui_key "(输入 0 返回主面板)"): "
            ;;
    esac

    if [[ $is_opt_msg ]]; then
        msg "$is_opt_msg"
    fi
    if [[ ${#is_tmp_list[@]} -gt 0 ]]; then
        show_list "${is_tmp_list[@]}"
    fi

    while :; do
        echo -ne "$is_opt_input_msg"
        read -r REPLY

        if [[ "$REPLY" == "0" ]]; then
            echo
            ui_cancel_msg
            sleep 0.5
            is_main_menu
            exit 0
        fi

        if [[ ! $REPLY && $is_emtpy_exit ]]; then
            exit
        fi
        if [[ ! $REPLY && $is_default_arg ]]; then
            printf -v "$is_ask_set" '%s' "$is_default_arg"
            export "${is_ask_set?}"
            break
        fi
        if [[ ! $REPLY && ! $is_default_arg && ! $is_emtpy_exit ]]; then
            continue
        fi

        if [[ $1 == "set_protocol" ]]; then
            if [[ "$REPLY" =~ ^([1-9]|1[0-9]|2[0-2])$ ]]; then
                printf -v "$is_ask_set" '%s' "${protocol_list[$REPLY - 1]}"
                export "${is_ask_set?}"
                break
            fi
        elif [[ ${#is_tmp_list[@]} -eq 0 ]]; then
            if [[ $(grep port <<< $is_ask_set) ]]; then
                if [[ ! $(is_test port "$REPLY") ]]; then
                    msg "$is_err 请输入正确的端口, 可选(1-65535)"
                    continue
                fi
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    msg "$is_err 无法使用 ($REPLY) 端口."
                    continue
                fi
            fi
            if [[ $(grep path <<< $is_ask_set) && ! $(is_test path "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的路径, 例如: /$tmp_uuid"
                continue
            fi
            if [[ $(grep uuid <<< $is_ask_set) && ! $(is_test uuid "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的 UUID, 例如: $tmp_uuid"
                continue
            fi
            if [[ $(grep ^y$ <<< $is_ask_set) ]]; then
                if [[ $(grep -i ^y$ <<< "$REPLY") ]]; then
                    break
                fi
                msg "请输入 (y)"
                continue
            fi
            if [[ $REPLY ]]; then
                printf -v "$is_ask_set" '%s' "$REPLY"
                export "${is_ask_set?}"
                msg "使用: ${!is_ask_set}"
                break
            fi
        else
            if [[ $(is_test number "$REPLY") ]]; then
                is_ask_result=${is_tmp_list[$REPLY - 1]}
            fi
            if [[ $is_ask_result ]]; then
                printf -v "$is_ask_set" '%s' "$is_ask_result"
                export "${is_ask_set?}"
                msg "选择: ${!is_ask_set}"
                break
            fi
        fi

        msg "输入${is_err}"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}
