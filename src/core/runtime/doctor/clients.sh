#!/bin/bash

# One parse per file per scan; result stays in the caller's local doctor_node array.
runtime_doctor_read_node() {
    local record value
    local jq_options=()
    [[ ${OSTYPE:-} == msys* ]] && jq_options+=(-b)
    record=$(jq "${jq_options[@]}" -je '
        def present: type == "string" and length > 0;
        . as $root | .inbounds[0] |
        [.type, .transport.type, (.tls.enabled // false), (.tls.reality.enabled // false),
         (if .type == "vless" or .type == "vmess" then (.users[0].uuid | present)
          elif .type == "trojan" or .type == "hysteria2" then (.users[0].password | present)
          elif .type == "tuic" then ((.users[0].uuid | present) and (.users[0].password | present))
          elif .type == "shadowsocks" then ((.method | present) and (.password | present))
          elif .type == "socks" then ((.users[0].username | present) and (.users[0].password | present))
          else true end | if . then 1 else 0 end),
         .tls.certificate_path, .tls.key_path, .listen_port, .users[0].uuid,
         .tls.server_name, .tls.reality.handshake.server, .tls.reality.private_key,
         ([$root.outbounds[]? | (.tag // "") | select(startswith("public_key_"))][0]),
         .tls.reality.short_id[0]]
        | map(if . == null then "" else tostring end)
        | if any(.[]; contains("\u001e")) then error("invalid field separator")
          else .[] + "\u001e" end
    ' "$1" 2> /dev/null) || return 1
    doctor_node=()
    while IFS= read -r -d $'\x1e' value; do doctor_node+=("$value"); done <<< "$record"
    return 0
}

runtime_doctor_client_compat() {
    local doctor_node=()
    local conf_file="" conf_name="" inbound_type="" transport_type="" tls_enabled="" reality_enabled=""
    local certificate_path="" key_path="" credential_ok=""
    local export_count=0 direct_count=0 invalid_count=0 field_issue_count=0 tls_issue_count=0
    local trojan_count=0 hysteria2_count=0 tuic_count=0 vmess_quic_count=0 pinned_count=0
    local conf_files=() invalid_items=() field_items=() tls_items=() unsupported_items=()
    local trojan_items=() hysteria2_items=() tuic_items=() vmess_quic_items=()

    if [[ ! -d $is_conf_dir ]]; then
        runtime_doctor_warn "客户端兼容: 节点配置目录不存在，无法扫描"
        return
    fi
    if ! command -v jq > /dev/null 2>&1; then
        runtime_doctor_warn "客户端兼容: jq 缺失，无法扫描协议类型"
        return
    fi

    mapfile -t conf_files < <(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort)
    if [[ ${#conf_files[@]} -eq 0 ]]; then
        runtime_doctor_info "客户端兼容: 未发现节点配置"
        return
    fi

    for conf_file in "${conf_files[@]}"; do
        conf_name=${conf_file##*/}
        if ! runtime_doctor_read_node "$conf_file"; then
            ((invalid_count++))
            invalid_items+=("$conf_name")
            continue
        fi
        inbound_type=${doctor_node[0]}
        transport_type=${doctor_node[1]}
        tls_enabled=${doctor_node[2]}
        reality_enabled=${doctor_node[3]}
        credential_ok=${doctor_node[4]}
        certificate_path=${doctor_node[5]}
        key_path=${doctor_node[6]}
        case $inbound_type in
            direct) ((direct_count++)) ;;
            vless | vmess | trojan | hysteria2 | tuic | shadowsocks | socks) ;;
            *) unsupported_items+=("$conf_name:$inbound_type") ;;
        esac

        if [[ $inbound_type != "direct" && $inbound_type ]]; then
            ((export_count++))
        fi
        if [[ $credential_ok -eq 0 ]]; then
            ((field_issue_count++))
            field_items+=("$conf_name")
        fi

        if [[ $tls_enabled == "true" && $reality_enabled != "true" ]]; then
            if [[ -z $certificate_path || -z $key_path || ! -f $certificate_path || ! -f $key_path ]]; then
                ((tls_issue_count++))
                tls_items+=("$conf_name")
            fi
        fi

        case $inbound_type in
            trojan)
                if [[ -z $transport_type ]]; then
                    ((trojan_count++))
                    trojan_items+=("$conf_name")
                fi
                ;;
            hysteria2)
                ((hysteria2_count++))
                hysteria2_items+=("$conf_name")
                ;;
            tuic)
                ((tuic_count++))
                tuic_items+=("$conf_name")
                ;;
            vmess)
                if [[ $transport_type == "quic" ]]; then
                    ((vmess_quic_count++))
                    vmess_quic_items+=("$conf_name")
                fi
                ;;
        esac
    done

    if [[ $invalid_count -gt 0 ]]; then
        runtime_doctor_warn "协议导出: $invalid_count 个 JSON 配置无法解析"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${invalid_items[@]}")"
    fi
    if [[ $field_issue_count -gt 0 ]]; then
        runtime_doctor_warn "协议导出: $field_issue_count 个配置缺少 UUID、密码或加密方法"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${field_items[@]}")"
    else
        runtime_doctor_ok "协议导出: $export_count 个可分享节点的身份字段完整"
    fi
    if [[ $tls_issue_count -gt 0 ]]; then
        runtime_doctor_warn "TLS 配置: $tls_issue_count 个节点的证书或私钥文件缺失"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${tls_items[@]}")"
    else
        runtime_doctor_ok "TLS 配置: 已启用 TLS 的节点证书路径可读"
    fi
    if [[ ${#unsupported_items[@]} -gt 0 ]]; then
        runtime_doctor_warn "协议导出: 发现当前脚本未识别的入站类型"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${unsupported_items[@]}")"
    fi
    if [[ $direct_count -gt 0 ]]; then
        runtime_doctor_info "协议导出: direct 入站 $direct_count 个仅用于端口转发，不生成代理分享链接"
    fi

    pinned_count=$((trojan_count + hysteria2_count + tuic_count + vmess_quic_count))
    if [[ $pinned_count -gt 0 ]]; then
        query_tls_pin_reset
        query_tls_pin_prepare
        if [[ $tls_pin_error ]]; then
            runtime_doctor_warn "证书固定: $tls_pin_error"
        else
            runtime_doctor_ok "证书固定: 可为 $pinned_count 个自签证书节点生成分享指纹"
            runtime_doctor_info "证书 SHA256: $tls_pin_cert_sha256_hex"
        fi
    fi
    if [[ $trojan_count -gt 0 ]]; then
        runtime_doctor_info "Trojan: $trojan_count 个无域名/自签证书节点只使用 pcs，不再下发 insecure/allowInsecure"
        msg "  - Trojan: $(runtime_doctor_join_limited 6 "${trojan_items[@]}")"
    fi
    if [[ $pinned_count -gt 0 ]]; then
        if [[ $hysteria2_count -gt 0 ]]; then
            msg "  - Hysteria2: $(runtime_doctor_join_limited 6 "${hysteria2_items[@]}")"
            msg "    导出: 官方要求 insecure=1 + pinSHA256；禁止缺少 pinSHA256 的单独 insecure"
        fi
        if [[ $tuic_count -gt 0 ]]; then
            msg "  - TUIC: $(runtime_doctor_join_limited 6 "${tuic_items[@]}")"
            msg "    导出: 通用 URI 使用 insecure=1 + pcs；sing-box 应按 sb info 的公钥指纹片段关闭 insecure"
        fi
        if [[ $vmess_quic_count -gt 0 ]]; then
            msg "  - VMess-QUIC: $(runtime_doctor_join_limited 6 "${vmess_quic_items[@]}")"
            msg "    导出: VMess JSON 只携带 pcs，不再下发 insecure；长期仍建议迁移到 Reality/CFtunnel"
        fi
        runtime_doctor_ok "Xray 迁移: Trojan/VMess-QUIC 已使用 pcs 替代 allowInsecure"
        runtime_doctor_info "已导入客户端的旧节点不会自动更新，请重新运行 sb url <配置名> 并重新导入"
    else
        runtime_doctor_ok "证书固定: 未发现需要自签证书分享指纹的节点"
    fi
}

runtime_doctor_reality() {
    local doctor_node=()
    local conf_file="" conf_name="" inbound_type="" reality_enabled=""
    local port="" uuid="" server_name="" handshake_server="" private_key="" public_key="" short_id=""
    local reality_count=0 field_issue_count=0 short_id_issue_count=0 listen_issue_count=0 listen_unchecked=0
    local conf_files=() field_items=() short_id_items=() listen_items=()

    if [[ ! -d $is_conf_dir ]] || ! command -v jq > /dev/null 2>&1; then
        return
    fi

    mapfile -t conf_files < <(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort)
    for conf_file in "${conf_files[@]}"; do
        runtime_doctor_read_node "$conf_file" || continue
        inbound_type=${doctor_node[0]}
        reality_enabled=${doctor_node[3]}
        if [[ $inbound_type != vless || $reality_enabled != true ]]; then continue; fi
        ((reality_count++))
        conf_name=${conf_file##*/}
        port=${doctor_node[7]}
        uuid=${doctor_node[8]}
        server_name=${doctor_node[9]}
        handshake_server=${doctor_node[10]}
        private_key=${doctor_node[11]}
        public_key=${doctor_node[12]}
        short_id=${doctor_node[13]}

        if [[ ! $port =~ ^[0-9]+$ || -z $uuid || -z $server_name || -z $private_key || -z $public_key || $handshake_server != "$server_name" ]]; then
            ((field_issue_count++))
            field_items+=("$conf_name")
        fi
        if [[ ! $short_id =~ ^[0-9a-fA-F]{1,8}$ ]]; then
            ((short_id_issue_count++))
            short_id_items+=("$conf_name")
        fi
        if [[ $port =~ ^[0-9]+$ ]]; then
            if runtime_doctor_port_listening "$port" tcp; then
                :
            else
                case $? in
                    1)
                        ((listen_issue_count++))
                        listen_items+=("$conf_name:$port/tcp")
                        ;;
                    2) listen_unchecked=1 ;;
                esac
            fi
        fi
    done

    if [[ $reality_count -eq 0 ]]; then
        runtime_doctor_info "VLESS-REALITY: 未发现配置"
        return
    fi

    runtime_doctor_info "VLESS-REALITY 使用 TCP；Hysteria2 使用 UDP，两者端口可用性需要分别检查"
    if [[ $field_issue_count -gt 0 ]]; then
        runtime_doctor_warn "VLESS-REALITY: $field_issue_count 个配置缺少关键字段或 SNI/握手目标不一致"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${field_items[@]}")"
    else
        runtime_doctor_ok "VLESS-REALITY: $reality_count 个配置的 UUID、SNI、密钥和握手目标完整"
    fi
    if [[ $short_id_issue_count -gt 0 ]]; then
        runtime_doctor_warn "VLESS-REALITY: $short_id_issue_count 个旧配置未使用明确 Short ID，部分客户端可能导入失败"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${short_id_items[@]}")"
        msg "  - 修复: 执行 sb change <配置名> key auto，重新导入包含 sid 的链接"
    else
        runtime_doctor_ok "VLESS-REALITY: Short ID 格式有效"
    fi
    if [[ $listen_issue_count -gt 0 ]]; then
        runtime_doctor_warn "VLESS-REALITY: 未检测到 $listen_issue_count 个 TCP 端口正在监听"
        msg "  - 配置: $(runtime_doctor_join_limited 6 "${listen_items[@]}")"
    elif [[ $listen_unchecked -eq 0 ]]; then
        runtime_doctor_ok "VLESS-REALITY: 本机 TCP 监听正常"
    fi
    runtime_doctor_info "即使本机监听正常，云厂商安全组仍需单独放行对应 TCP 端口"
}
