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

            snapshot_ensure "write-create"
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

            if [[ $is_config_file ]]; then
                is_no_del_msg=1
                del $is_config_file
            fi

            printf '%s\n' "$is_new_json" > "$is_json_file" || return 1

            if [[ $is_new_protocol == 'CFtunnel' && $cf_token ]]; then
                install_cloudflared
                create_cftunnel_service "$cf_token" "$port"
            fi

            if [[ $is_new_install ]]; then
                create config.json
            fi
            if [[ $is_caddy && $host && ! $is_no_auto_tls ]]; then
                create caddy $net
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
            is_log='log:{output:"/var/log/'$is_core'/access.log",level:"info","timestamp":true}'
            is_dns='dns:{}'
            is_ntp='ntp:{"enabled":true,"server":"time.apple.com"},'
            if [[ -f $is_config_json ]]; then
                if [[ $(jq .ntp.enabled $is_config_json) != "true" ]]; then
                    is_ntp=
                fi
            else
                if [[ ! $is_ntp_on ]]; then
                    is_ntp=
                fi
            fi
            is_outbounds='outbounds:[{tag:"direct",type:"direct"}]'
            is_server_config_json=$(jq "{$is_log,$is_dns,$is_ntp$is_outbounds}" <<< {})
            cat <<< $is_server_config_json > $is_config_json
            manage restart &
            ;;
    esac
}
