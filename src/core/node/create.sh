#!/bin/bash

write_create() {
    case $1 in
        server)
            is_tls=none
            get new
            is_listen="::"

            if [[ $is_new_protocol == 'CFtunnel' ]]; then
                is_listen="127.0.0.1"
            fi

            local safe_remark="${custom_remark//\//_}"
            if [[ -z "$safe_remark" ]]; then
                safe_remark="luopojunzi"
            fi

            if [[ $host ]]; then
                is_config_name=$2-${safe_remark}-${host}.json
                if [[ $is_new_protocol != 'CFtunnel' ]]; then
                    is_listen="127.0.0.1"
                fi
            else
                is_config_name=$2-${safe_remark}-${port}.json
            fi

            is_json_file=$is_conf_dir/$is_config_name

            node_prepare_protocol "$2" || return 1
            is_new_json=$(node_build_config) || {
                err "节点配置生成失败"
                return 1
            }
            if [[ $is_test_json ]]; then
                return
            fi
            if [[ $is_gen ]]; then
                msg
                jq <<< $is_new_json
                msg
                return
            fi

            snapshot_ensure "write-create" || return 1
            if [[ $is_dry_run ]]; then
                msg "DRY-RUN: 将创建配置文件 -> $is_json_file"
                msg "DRY-RUN: 协议=$is_new_protocol 端口=$port 备注=$safe_remark"
                if [[ $host ]]; then msg "DRY-RUN: host=$host"; fi
                if [[ $is_servername ]]; then msg "DRY-RUN: serverName=$is_servername"; fi
                return
            fi

            case $net in
                tuic | trojan | hysteria2 | quic | h2)
                    runtime_ensure_tls || {
                        err "TLS 证书生成失败，未写入节点配置"
                        return 1
                    }
                    ;;
            esac

            local previous_name=${is_config_file:-} previous_port=""
            if [[ $previous_name == *CFtunnel* ]]; then
                previous_port=$(jq -r '.inbounds[0].listen_port' "$is_conf_dir/$previous_name") || return 1
                previous_port=${previous_port%$'\r'}
            fi
            if [[ $is_new_install && ! -f $is_config_json ]]; then
                create config.json defer-restart || return 1
            fi
            node_commit_config node "$is_new_json" "$is_config_name" "$previous_name" || return 1
            write_cleanup_replaced_node "$previous_name" "$previous_port"
            write_add_install_caddy_if_needed || return 1

            if [[ $is_new_protocol == 'CFtunnel' && $cf_token ]]; then
                install_cloudflared
                create_cftunnel_service "$cf_token" "$port"
            fi

            if [[ $is_caddy && $host && ! $is_no_auto_tls ]]; then
                create caddy "$net" || return 1
            fi
            manage restart &
            ;;
        client)
            is_tls=tls
            is_client=1
            get info $2
            if [[ ! $is_client_id_json ]]; then
                err "($is_config_name) 不支持生成客户端配置."
            fi
            is_new_json=$(jq '{outbounds:[{tag:'\"$is_config_name\"',protocol:'\"$is_protocol\"','"$is_client_id_json"','"$is_stream"'}]}' <<< {})
            msg
            jq <<< $is_new_json
            msg
            ;;
        caddy)
            if [[ ${is_dry_run:-} ]]; then
                msg "DRY-RUN: 将更新 Caddy 配置并重启，本次不执行"
                return 0
            fi
            load caddy.sh
            if [[ $is_install_caddy ]]; then
                caddy_config new
            fi
            if [[ ! $(grep "$is_caddy_conf" $is_caddyfile) ]]; then
                msg "import $is_caddy_conf/*.conf" >> $is_caddyfile
            fi
            if [[ ! -d $is_caddy_conf ]]; then
                mkdir -p $is_caddy_conf
            fi
            caddy_config $2
            manage restart caddy &
            ;;
        config.json)
            if [[ ${is_dry_run:-} ]]; then
                msg "DRY-RUN: 将校验并重建主配置 -> $is_config_json，本次不写入或重启"
                return 0
            fi
            is_server_config_json=$(node_build_main_config) || return 1
            snapshot_ensure "write-main-config" || return 1
            node_commit_config main "$is_server_config_json" || return 1
            if [[ ${2:-} != defer-restart ]]; then manage restart & fi
            ;;
    esac
}
