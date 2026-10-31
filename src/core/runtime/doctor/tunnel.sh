#!/bin/bash

# Inspect unit configuration only; never print it, its Environment values,
# credentials, /proc command lines or debug endpoint responses.
runtime_doctor_cloudflared_security() {
    local unit config token_file metadata issue=0 count=0

    command -v systemctl > /dev/null 2>&1 || return 0
    while IFS= read -r unit; do
        [[ $unit =~ ^cftunnel-[1-9][0-9]{0,4}\.service$ ]] || continue
        ((count += 1))
        if ! config=$(systemctl cat "$unit" 2> /dev/null) || [[ ! $config ]]; then
            runtime_doctor_warn "cloudflared 安全: $unit 的服务配置未核实"
            issue=1
            continue
        fi
        if [[ $(grep -Ec '^[[:space:]]*ExecStart=' <<< "$config") != 1 ]] ||
            grep -Eq '^[[:space:]]*(Environment|EnvironmentFile|ExecStartPre)=|^[[:space:]]*ExecStart=.*--config([=[:space:]]|$)' <<< "$config"; then
            runtime_doctor_warn "cloudflared 安全: $unit 含服务覆盖/环境/自定义配置，凭据和 metrics 需要人工复核（内容不显示）"
            issue=1
        fi
        if grep -Eq '^[[:space:]]*(ExecStart|Environment|EnvironmentFile)=.*(--token([=[:space:]]|$)|--credentials-contents([=[:space:]]|$)|TUNNEL_TOKEN=)' <<< "$config"; then
            runtime_doctor_warn "cloudflared 凭据: $unit 仍在服务命令或环境中使用明文 token（内容不显示）"
            runtime_doctor_info "维护窗口内迁移到 root 专用 token 文件；不自动改写、迁移或重启已有服务."
            issue=1
        fi
        if ! grep -Eq '^[[:space:]]*ExecStart=.*--metrics[=[:space:]]+(127\.0\.0\.1|\[::1\]):[0-9]+([[:space:]]|$)' <<< "$config"; then
            runtime_doctor_warn "cloudflared metrics: $unit 未在 ExecStart 显式限定回环监听；需核对覆盖配置和实际监听，不据此认定已公网暴露"
            issue=1
        fi
        if grep -Eq '^[[:space:]]*ExecStart=.*--token-file([=[:space:]]|$)' <<< "$config"; then
            token_file="${is_core_dir:-/etc/sing-box}/cftunnel/${unit#cftunnel-}"
            token_file=${token_file%.service}.token
            if [[ -L ${token_file%/*} || -L $token_file || ! -f $token_file ]]; then
                runtime_doctor_warn "cloudflared 凭据: $unit 的受管 token 文件缺失、为符号链接或使用自定义路径，需人工核查"
                issue=1
            else
                metadata=$(stat -c '%a:%u' -- "$token_file" 2> /dev/null) || metadata=unknown
                if [[ $metadata != 600:0 && $metadata != 400:0 ]]; then
                    runtime_doctor_warn "cloudflared 凭据: $unit 的 token 文件权限/属主未达到 root 专用要求"
                    issue=1
                fi
            fi
        else
            runtime_doctor_warn "cloudflared 凭据: $unit 未使用受管 token 文件，保护状态未核实"
            issue=1
        fi
    done < <(systemctl list-unit-files --type=service --no-legend --no-pager 'cftunnel-*.service' 2> /dev/null | awk '{print $1}')
    if [[ $count -gt 0 && $issue -eq 0 ]]; then
        runtime_doctor_ok "cloudflared 服务配置: 凭据与回环 metrics 静态检查通过；不代表运行进程或公网隧道已验收"
    fi
    return "$issue"
}
