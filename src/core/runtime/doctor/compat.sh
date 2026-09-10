#!/bin/bash

runtime_doctor_sing_box_version() {
    local minimum recommended

    minimum=$(sing_box_minimum_supported_version)
    recommended=$(sing_box_recommended_stable_version)
    if [[ -z ${is_core_ver:-} ]]; then
        runtime_doctor_warn "sing-box 版本: 无法识别，建议检查核心文件"
        return 1
    fi
    if version_is_less_than "$is_core_ver" "$minimum"; then
        runtime_doctor_warn "sing-box 版本: $is_core_ver，建议升级到 $minimum 或更高稳定版"
        runtime_doctor_info "1.13.19 包含读取不可信二进制数据时的内存分配修复."
        return 1
    fi
    if version_is_prerelease "$is_core_ver"; then
        runtime_doctor_warn "sing-box 版本: $is_core_ver 是预发布版，推荐稳定版为 $recommended"
        runtime_doctor_info "默认更新只跟随正式 Release；如无测试需求，建议切回稳定版."
        return 1
    fi
    if version_is_less_than "$is_core_ver" "$recommended"; then
        runtime_doctor_warn "sing-box 版本: $is_core_ver 已达到最低兼容版本 $minimum，但低于推荐稳定版 $recommended"
        runtime_doctor_info "升级前请先处理本次 doctor 列出的 1.14 配置兼容项."
        return 1
    fi
    runtime_doctor_ok "sing-box 版本: $is_core_ver，已达到推荐稳定版基线 $recommended"
}

runtime_doctor_cloudflared_version() {
    local version

    command -v cloudflared > /dev/null 2>&1 || return 0
    version=$(cloudflared --version 2> /dev/null | awk 'NR == 1 {print $3}')
    if [[ -z $version ]]; then
        runtime_doctor_warn "cloudflared 版本: 无法识别"
        return 1
    fi
    if cloudflared_version_is_blocked "$version"; then
        runtime_doctor_warn "cloudflared 版本: $version 已被官方标记为不可使用"
        runtime_doctor_info "请执行 sb update cloudflared，升级到 2026.8.2 或更高版本."
        return 1
    fi
    runtime_doctor_ok "cloudflared 版本: $version"
}

runtime_doctor_compat_issue_label() {
    case $1 in
        legacy_dns_server) printf '%s\n' "旧 DNS server" ;;
        legacy_dns_special_server) printf '%s\n' "特殊旧 DNS server" ;;
        legacy_dns_server_options) printf '%s\n' "旧 DNS server 策略字段" ;;
        legacy_dns_fakeip) printf '%s\n' "旧 FakeIP" ;;
        legacy_dns_outbound_rule) printf '%s\n' "旧 DNS outbound 规则" ;;
        dns_independent_cache) printf '%s\n' "independent_cache" ;;
        cache_store_rdrc) printf '%s\n' "store_rdrc" ;;
        dns_legacy_address_filter) printf '%s\n' "旧 DNS 地址过滤" ;;
        dns_legacy_strategy) printf '%s\n' "旧 DNS strategy" ;;
        dns_rule_set_accept_empty) printf '%s\n' "rule_set_ip_cidr_accept_empty" ;;
        inline_acme) printf '%s\n' "内联 TLS ACME" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

runtime_doctor_sing_box_config_compat() {
    local config_file config_name issue_key issue_count label detail=""
    local issue_total=0 issue_config_count=0
    local config_files=() node_configs=() issue_items=() manual_files=()

    command -v jq > /dev/null 2>&1 || return 0
    [[ -f $is_config_json ]] && config_files+=("$is_config_json")
    if [[ -d $is_conf_dir ]]; then
        mapfile -t node_configs < <(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort)
        config_files+=("${node_configs[@]}")
    fi

    for config_file in "${config_files[@]}"; do
        jq empty "$config_file" > /dev/null 2>&1 || continue
        detail=""
        while IFS=$'\t' read -r issue_key issue_count; do
            issue_count=${issue_count%$'\r'}
            [[ $issue_key && $issue_count =~ ^[0-9]+$ ]] || continue
            label=$(runtime_doctor_compat_issue_label "$issue_key")
            detail="${detail:+$detail, }$label=$issue_count"
            ((issue_total += issue_count))
        done < <(compat_sing_box_issue_report "$config_file")
        if [[ $detail ]]; then
            config_name=$(basename "$config_file")
            issue_items+=("$config_name: $detail")
            ((issue_config_count++))
        fi
    done

    if [[ $issue_total -eq 0 ]]; then
        runtime_doctor_ok "sing-box 配置兼容: 未发现已知旧格式或弃用字段"
        return 0
    fi

    runtime_doctor_warn "sing-box 配置兼容: $issue_config_count 个文件包含 $issue_total 项待迁移配置"
    for detail in "${issue_items[@]}"; do
        msg "  - $detail"
    done
    mapfile -t manual_files < <(compat_sing_box_114_manual_files "$is_config_json" "$is_conf_dir")
    if [[ ${#manual_files[@]} -gt 0 ]]; then
        runtime_doctor_info "以下配置在升级 sing-box 1.14 前需要手动迁移:"
        for config_file in "${manual_files[@]}"; do
            msg "  - $config_file"
        done
    else
        runtime_doctor_info "普通旧 DNS address 可由 sb update core 在候选核心校验通过后自动迁移."
    fi
    runtime_doctor_info "其余弃用字段建议按提示逐步清理，为 sing-box 1.16 做准备."
    return 1
}
