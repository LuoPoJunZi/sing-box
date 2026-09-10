#!/bin/bash

runtime_doctor() {
    local ok=0 warn_count=0 fail=0 conf_count=0
    local domain_count=0 snapshot_count=0
    local host_ip="" host_ip6="" dns_test=""
    local doctor_missing_cmds=""
    local fail_core_bin=0 fail_config=0 fail_conf_dir=0 fail_check=0 fail_systemd=0
    local warn_service=0 warn_caddy=0 warn_network=0 warn_dns=0 warn_jq=0 warn_jq_version=0
    local warn_core_version=0 warn_cloudflared_version=0 warn_sing_box_compat=0
    local jq_version=""

    msg "\n============= 系统诊断 (doctor) ============="

    runtime_doctor_system_info

    msg "------------- 终端颜色 -------------"
    runtime_doctor_color

    msg "------------- 依赖检查 -------------"
    runtime_doctor_cmd wget
    runtime_doctor_cmd curl
    runtime_doctor_cmd tar
    runtime_doctor_cmd jq
    runtime_doctor_cmd openssl
    runtime_doctor_cmd sha256sum
    if ! command -v jq > /dev/null 2>&1; then
        warn_jq=1
    else
        jq_version=$(jq --version 2> /dev/null | sed 's/^jq-//')
        if [[ $jq_version && $(printf '%s\n' "$jq_version" 1.8.2 | sort -V | head -n 1) != 1.8.2 ]]; then
            runtime_doctor_warn "jq 版本偏旧: $jq_version，建议升级到 1.8.2 或更高版本"
            warn_jq_version=1
        fi
    fi
    if command -v ss > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: ss ($(command -v ss))"
    elif command -v netstat > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: netstat ($(command -v netstat))"
    else
        runtime_doctor_warn "依赖缺失: ss/netstat，无法检查端口监听"
    fi

    msg "------------- 文件与配置 -------------"
    if [[ -x $is_core_bin ]]; then
        runtime_doctor_ok "核心二进制: $is_core_bin"
        if ! runtime_doctor_sing_box_version; then
            warn_core_version=1
        fi
    else
        runtime_doctor_fail "核心二进制不存在: $is_core_bin"
        fail_core_bin=1
    fi

    if [[ -f $is_config_json ]]; then
        runtime_doctor_ok "主配置存在: $is_config_json"
    else
        runtime_doctor_fail "主配置缺失: $is_config_json"
        fail_config=1
    fi

    if [[ -d $is_conf_dir ]]; then
        conf_count=$(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | wc -l)
        runtime_doctor_ok "节点配置数量: $conf_count"
    else
        runtime_doctor_fail "节点配置目录缺失: $is_conf_dir"
        fail_conf_dir=1
    fi

    if ! runtime_doctor_sing_box_config_compat; then
        warn_sing_box_compat=1
    fi

    runtime_doctor_manifest
    runtime_doctor_disk "$is_core_dir" "/etc/sing-box"
    runtime_doctor_disk "$is_log_dir" "/var/log/sing-box"

    msg "------------- 客户端兼容 -------------"
    runtime_doctor_client_compat

    msg "------------- VLESS / Reality -------------"
    runtime_doctor_reality

    msg "------------- 服务与端口 -------------"
    if ! runtime_doctor_cloudflared_version; then
        warn_cloudflared_version=1
    fi
    if [[ $fail_systemd -eq 0 ]]; then
        if systemctl list-unit-files "$is_core.service" 2> /dev/null | grep -q "^$is_core.service"; then
            runtime_doctor_ok "服务单元存在: $is_core.service"
        else
            runtime_doctor_warn "服务单元缺失: $is_core.service"
        fi

        if systemctl is-active --quiet "$is_core" 2> /dev/null; then
            runtime_doctor_ok "服务状态: $is_core 运行中"
        else
            runtime_doctor_warn "服务状态: $is_core 未运行"
            warn_service=1
        fi

        if [[ $is_caddy ]]; then
            if systemctl is-active --quiet caddy 2> /dev/null; then
                runtime_doctor_ok "服务状态: caddy 运行中"
            else
                runtime_doctor_warn "服务状态: caddy 未运行"
                warn_caddy=1
            fi
        fi
    fi

    runtime_doctor_listen_ports

    msg "------------- 配置校验 -------------"
    if [[ -x $is_core_bin && -f $is_config_json ]]; then
        if json_check_core_config; then
            runtime_doctor_ok "配置校验: sing-box check 通过"
        else
            runtime_doctor_fail "配置校验: sing-box check 未通过"
            fail_check=1
        fi
    fi

    msg "------------- 网络检查 -------------"
    if command -v curl > /dev/null 2>&1; then
        host_ip=$(curl -s4m6 https://icanhazip.com 2> /dev/null || true)
        host_ip6=$(curl -s6m6 https://icanhazip.com 2> /dev/null || true)
        if [[ $host_ip ]]; then
            runtime_doctor_ok "出站网络: IPv4 可访问公网 ($host_ip)"
        else
            runtime_doctor_warn "出站网络: 无法快速获取公网 IPv4"
            warn_network=1
        fi
        if [[ $host_ip6 ]]; then
            runtime_doctor_ok "出站网络: IPv6 可访问公网 ($host_ip6)"
        else
            runtime_doctor_warn "出站网络: 未检测到可用公网 IPv6"
        fi
    else
        runtime_doctor_warn "出站网络: curl 缺失，无法检查公网 IP"
        warn_network=1
    fi

    if command -v wget > /dev/null 2>&1; then
        dns_test=$(wget -qO- -t1 -T6 --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=github.com&type=a" 2> /dev/null || true)
        if [[ $dns_test =~ \"Status\":0 ]]; then
            runtime_doctor_ok "DNS over HTTPS: one.one.one.one 可用"
        else
            runtime_doctor_warn "DNS over HTTPS: one.one.one.one 测试失败"
            warn_dns=1
        fi
    else
        runtime_doctor_warn "DNS over HTTPS: wget 缺失，无法检查 DoH"
        warn_dns=1
    fi

    msg "------------- 运行资料 -------------"
    if declare -F domain_collect_pool > /dev/null 2>&1; then
        domain_count=$(domain_collect_pool global 2> /dev/null | wc -l)
        runtime_doctor_ok "Reality 域名池条目: $domain_count"
    fi
    if [[ -d $is_sh_dir/snapshots ]]; then
        snapshot_count=$(find "$is_sh_dir/snapshots" -maxdepth 1 -type f -name '*.tar.gz' 2> /dev/null | wc -l)
        runtime_doctor_ok "配置快照数量: $snapshot_count"
    else
        runtime_doctor_warn "配置快照目录不存在: $is_sh_dir/snapshots"
    fi

    msg "----------------------------------------------"
    msg "诊断结果: OK=$ok WARN=$warn_count FAIL=$fail"
    if [[ $fail -gt 0 || $warn_count -gt 0 ]]; then
        msg "------------- 建议修复动作 -------------"
        if [[ $doctor_missing_cmds ]]; then
            msg "1) 依赖缺失：请先安装:${doctor_missing_cmds}"
        fi
        if [[ $fail_systemd -eq 1 ]]; then
            msg "2) systemd 不可用：请确认当前系统支持 systemctl，或改用受支持的 VPS 系统"
        fi
        if [[ $fail_core_bin -eq 1 ]]; then
            msg "3) 核心缺失：尝试执行 sb update core 或重新安装脚本"
        fi
        if [[ $fail_config -eq 1 || $fail_conf_dir -eq 1 ]]; then
            msg "4) 配置缺失：可用 sb rollback 恢复最近快照，或 sb backup list 先检查快照"
        fi
        if [[ $fail_check -eq 1 ]]; then
            msg "5) 配置非法：先执行 sb backup create pre-fix，再用 sb fix-all / sb change 修复"
        fi
        if [[ $warn_service -eq 1 ]]; then
            msg "6) 核心未运行：执行 sb start"
        fi
        if [[ $warn_caddy -eq 1 ]]; then
            msg "7) Caddy 未运行：执行 sb start caddy"
        fi
        if [[ $warn_network -eq 1 || $warn_dns -eq 1 ]]; then
            msg "8) 网络或 DNS 异常：检查服务器出站策略、DNS 解析与防火墙规则"
        fi
        if [[ $warn_jq -eq 1 ]]; then
            msg "9) jq 缺失会影响 JSON 读写：请安装 jq 后再执行配置修改"
        fi
        if [[ $warn_jq_version -eq 1 ]]; then
            msg "10) jq 版本偏旧：请通过系统包管理器升级，或重新安装脚本以获取已校验的 jq 1.8.2"
        fi
        if [[ $warn_core_version -eq 1 ]]; then
            msg "11) sing-box 版本未达推荐稳定基线：先处理上方兼容项，再执行 sb update core"
        fi
        if [[ $warn_sing_box_compat -eq 1 ]]; then
            msg "12) 配置兼容：先执行 sb backup create pre-migrate，再按上方文件清单迁移；普通旧 DNS address 可由核心更新安全转换"
        fi
        if [[ $warn_cloudflared_version -eq 1 ]]; then
            msg "13) cloudflared 版本异常：执行 sb update cloudflared，禁止继续使用 2026.8.0/2026.8.1"
        fi
        msg "----------------------------------------"
    fi
    msg "==============================================\n"
}
