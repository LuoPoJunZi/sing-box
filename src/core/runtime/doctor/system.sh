#!/bin/bash

runtime_doctor_cmd() {
    local cmd=$1 label=${2:-$1}
    if command -v "$cmd" > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: $label ($(command -v "$cmd"))"
    else
        runtime_doctor_warn "依赖缺失: $label"
        doctor_missing_cmds="${doctor_missing_cmds} ${cmd}"
    fi
}

runtime_doctor_disk() {
    local target_path=$1 label=$2 usage=""

    if [[ ! -e $target_path ]]; then
        target_path=$(dirname "$target_path")
    fi
    if [[ ! -e $target_path ]] || ! command -v df > /dev/null 2>&1; then
        runtime_doctor_warn "磁盘空间: 无法检查 $label"
        return
    fi

    usage=$(df -Pk "$target_path" 2> /dev/null | awk 'NR == 2 { gsub("%", "", $5); print $5 }')
    if [[ $usage =~ ^[0-9]+$ ]]; then
        if ((usage >= 90)); then
            runtime_doctor_warn "磁盘空间: $label 使用率 ${usage}% 偏高"
        else
            runtime_doctor_ok "磁盘空间: $label 使用率 ${usage}%"
        fi
    else
        runtime_doctor_warn "磁盘空间: 无法解析 $label 使用率"
    fi
}

runtime_doctor_color() {
    local reason=""

    if [[ -n ${NO_COLOR:-} ]]; then
        reason="NO_COLOR=1"
    elif [[ ${TERM:-} == dumb ]]; then
        reason="TERM=dumb"
    elif [[ ! -t 1 ]]; then
        reason="当前输出不是 TTY"
    fi

    if [[ $ui_color_enabled == 1 ]]; then
        runtime_doctor_ok "终端颜色: 已启用基础 ANSI 颜色 (30-37)"
        msg "颜色样例: $(ui_brand "青色标题") $(ui_success "绿色成功") $(ui_warn "黄色提醒") $(ui_error "红色错误") $(ui_muted "灰色提示")"
        runtime_doctor_info "如果上面的样例没有颜色，请检查终端配色方案或 SSH 客户端设置。"
    else
        runtime_doctor_info "终端颜色: 已关闭 (${reason:-原因未知})"
        runtime_doctor_info "这是预期的纯文本模式，适合日志复制、管道输出和 CI。"
    fi
}

runtime_doctor_port_listening() {
    local port=$1 mode=${2:-both} listen_args="-lntu"

    case $mode in
        tcp) listen_args="-lnt" ;;
        udp) listen_args="-lnu" ;;
    esac

    if command -v ss > /dev/null 2>&1; then
        ss -H "$listen_args" 2> /dev/null | awk '{print $5}' | grep -Eq "(^|:|\\.)${port}$"
        return
    fi
    if command -v netstat > /dev/null 2>&1; then
        netstat "$listen_args" 2> /dev/null | awk 'NR > 2 {print $4}' | grep -Eq "(^|:|\\.)${port}$"
        return
    fi
    return 2
}

runtime_doctor_listen_ports() {
    local port port_count=0 unchecked_count=0
    local ports=()

    if [[ ! -d $is_conf_dir ]]; then
        return
    fi

    mapfile -t ports < <(grep -Rho '"listen_port"[[:space:]]*:[[:space:]]*[0-9]\+' "$is_conf_dir" 2> /dev/null | grep -oE '[0-9]+' | sort -n | uniq)
    if [[ ${#ports[@]} -eq 0 ]]; then
        runtime_doctor_warn "监听端口: 未从节点配置中发现 listen_port"
        return
    fi

    msg "监听端口: ${ports[*]}"
    for port in "${ports[@]}"; do
        if runtime_doctor_port_listening "$port"; then
            ((port_count++))
        elif [[ $? -eq 2 ]]; then
            ((unchecked_count++))
        fi
    done

    if [[ $unchecked_count -gt 0 ]]; then
        runtime_doctor_warn "监听端口: 缺少 ss/netstat，无法确认端口监听状态"
    elif [[ $port_count -gt 0 ]]; then
        runtime_doctor_ok "监听端口: 已检测到 $port_count 个端口正在监听"
    else
        runtime_doctor_warn "监听端口: 未检测到配置端口在监听，若服务未启动请先执行 sb start"
    fi
}

runtime_doctor_manifest() {
    local manifest_file="$is_sh_dir/.install_manifest"
    local manifest_count=0

    if [[ -f $manifest_file ]]; then
        manifest_count=$(wc -l < "$manifest_file" 2> /dev/null)
        runtime_doctor_ok "安装清单: 已记录 $manifest_count 条托管项"
    else
        runtime_doctor_warn "安装清单: 未找到 $manifest_file，完全卸载时只能按兼容规则清理"
    fi
}

runtime_doctor_system_info() {
    local os_name="" kernel="" arch=""

    arch=$(uname -m 2> /dev/null)
    kernel=$(uname -r 2> /dev/null)
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release 2> /dev/null | cut -d= -f2- | tr -d '"')
    fi

    msg "系统: ${os_name:-unknown} / ${arch:-unknown} / kernel ${kernel:-unknown}"
    if command -v systemctl > /dev/null 2>&1; then
        runtime_doctor_ok "systemd: systemctl 可用"
    else
        runtime_doctor_fail "systemd: systemctl 不可用，本脚本无法正常管理服务"
        fail_systemd=1
    fi
}
