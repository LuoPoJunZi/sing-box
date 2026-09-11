#!/bin/bash

. "$is_sh_dir/src/core/node/add/prepare.sh"

write_add() {
    write_add_resolve_protocol "$@"
    if [[ ! $is_new_protocol ]]; then ask set_protocol; fi

    write_add_prepare_protocol_args "$@"
    if [[ $1 && ! $is_change ]]; then
        msg "\n使用协议: $is_new_protocol"
        is_err_tips="\n\n请使用: $(_green $is_core add $1 $is_add_opts) 来添加 $is_new_protocol 配置"
    fi

    if [[ $is_set_new_protocol ]]; then
        case $is_old_net in
            h2 | ws | httpupgrade)
                old_host=$host
                if [[ ! $is_use_tls ]]; then unset host is_no_auto_tls; fi
                ;;
            reality)
                net_type=
                if [[ ! $(grep -i reality <<< $is_new_protocol) ]]; then is_reality=; fi
                ;;
            ss) if [[ $(is_test uuid $ss_password) ]]; then uuid=$ss_password; fi ;;
        esac
        if [[ ! $(is_test uuid $uuid) ]]; then uuid=; fi
        if [[ $(is_test uuid $password) ]]; then uuid=$password; fi
    fi

    if [[ $is_no_auto_tls && ! $is_use_tls ]]; then err "$is_new_protocol 不支持手动配置 tls."; fi

    write_add_apply_cli_args "$@"
    if [[ $is_reality && ! $is_servername ]]; then
        is_servername=$(domain_pick_for_reality)
        if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
        if [[ $is_servername ]]; then msg "Reality 自动选择 serverName: $(_green $is_servername)"; fi
    fi

    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen && ! $is_dont_test_host ]]; then
            if [[ $(is_test port_used 80) || $(is_test port_used 443) ]]; then
                get_port
                is_http_port=$tmp_port
                get_port
                is_https_port=$tmp_port
                warn "端口 (80 或 443) 已经被占用, Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "请确定是否继续???"
                pause
            fi
            is_install_caddy=1
        fi
        if [[ ! $host ]]; then ask string host "请输入域名"; fi
        get host-test
    else
        if [[ $is_main_start ]]; then
            if [[ ! $port ]]; then
                get_port
                port=$tmp_port
                echo -e "\n--------------------------------------------------------"
                echo -e "端口分配: 已自动为您分配空闲端口 [$(ui_success "$port")]"
                echo -e "--------------------------------------------------------"
            fi

            if [[ $is_new_protocol == 'CFtunnel' ]]; then
                if [[ ! $cf_token ]]; then ask string cf_token "请输入 Cloudflare Tunnel Token"; fi
                if [[ ! $cf_domain ]]; then ask string cf_domain "请输入你准备为该节点绑定的 Cloudflare 域名 (例如 node1.example.com)"; fi
            fi

            case ${is_new_protocol,,} in
                socks)
                    if [[ ! $is_socks_user ]]; then ask string is_socks_user "请设置用户名"; fi
                    if [[ ! $is_socks_pass ]]; then ask string is_socks_pass "请设置密码"; fi
                    ;;
                shadowsocks)
                    if [[ ! $ss_method ]]; then ask set_ss_method; fi
                    if [[ ! $ss_password ]]; then ask string ss_password "请设置密码"; fi
                    ;;
            esac
        fi
    fi

    if [[ $is_new_protocol == 'Direct' ]]; then
        if [[ ! $door_addr ]]; then ask string door_addr "请输入目标地址"; fi
        if [[ ! $door_port ]]; then ask string door_port "请输入目标端口"; fi
    fi

    if [[ $ss_method == *2022* && ! ${is_dry_run:-} && ! ${is_gen:-} ]]; then
        if [[ $ss_password ]]; then
            is_test_json=1
            create server Shadowsocks || return 1
            if [[ ! $tmp_uuid ]]; then get_uuid; fi
            is_test_json_save=$is_conf_dir/tmp-test-$tmp_uuid
            cat <<< "$is_new_json" > $is_test_json_save
            $is_core_bin check -c $is_test_json_save &> /dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议不支持使用当前密码, 脚本将自动创建可用密码:)"
                ss_password=
                json_str=
            fi
            is_test_json=
            rm -f $is_test_json_save
        fi
    fi

    write_add_prompt_remark "$@"
    create server "$is_new_protocol" || return 1
    [[ ${is_dry_run:-} || ${is_gen:-} ]] && return 0
    info
}
