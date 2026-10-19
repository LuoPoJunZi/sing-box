#!/bin/bash

# Read local Go metadata only. No downloads, probing, configuration writes or
# service changes. Module replacements must not hide an older/forked x/net.
runtime_doctor_parse_go_build() {
    awk '
        function remember_go(value) {
            if (go_version != "" && go_version != value) go_version="unknown"
            else go_version=value
        }
        { sub(/\r$/, "") }
        $1 == "=>" && pending_net {
            net_version=($2 == "golang.org/x/net" ? $3 : "unknown-replacement")
            pending_net=0
            next
        }
        { pending_net=0 }
        $1 == "go" { remember_go($2) }
        $1 == "Environment:" {
            for (i=2; i<=NF; i++) if ($i ~ /^go[0-9]/) remember_go($i)
        }
        $0 ~ /:[[:space:]]+go[0-9][^[:space:]]*$/ { remember_go($NF) }
        $1 == "dep" && $2 == "golang.org/x/net" {
            if (seen_net++) net_conflict=1
            else net_version=$3
            pending_net=1
        }
        END {
            print "go\t" (go_version == "" ? "unknown" : go_version)
            print "x_net\t" (net_version == "" || net_conflict ? "unknown" : net_version)
        }
    '
}

runtime_doctor_go_build_report() {
    local label=$1 metadata=$2 field value go_version=unknown net_version=unknown
    local issue=0

    while IFS=$'\t' read -r field value; do
        case $field in
            go) go_version=$value ;;
            x_net) net_version=$value ;;
        esac
    done < <(runtime_doctor_parse_go_build <<< "$metadata")

    # Scope: GO-2026-6603 / GO-2026-6617 only, not a vulnerability scanner.
    if [[ $go_version =~ ^go[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        value=${go_version#go}
        if { version_is_at_least "$value" 1.26.9 && version_is_less_than "$value" 1.27.0; } || version_is_at_least "$value" 1.27.2; then
            runtime_doctor_ok "$label Go 编译版本: $go_version，达到已复核 HTTP/2 公告修复基线"
        else
            runtime_doctor_warn "$label Go 编译版本: $go_version，落在 GO-2026-6603/GO-2026-6617 受影响版本范围"
            issue=1
        fi
    else
        runtime_doctor_warn "$label Go 编译版本: 未核实 ($go_version)，不能据组件版本认定安全"
        issue=1
    fi

    if [[ $net_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if version_is_at_least "$net_version" 0.60.0; then
            runtime_doctor_ok "$label x/net: $net_version，达到已复核 HTTP/2 公告修复基线"
        else
            runtime_doctor_warn "$label x/net: $net_version，低于 GO-2026-6603/GO-2026-6617 修复版本 v0.60.0"
            issue=1
        fi
    else
        runtime_doctor_warn "$label x/net: 未核实 ($net_version)，缺失或自定义替换不等于不受影响"
        issue=1
    fi
    if [[ $issue -eq 1 ]]; then
        runtime_doctor_info "请结合实际 HTTP/2 监听和配置核查；优先采用上游安全构建。工具链基线为 Go 1.26.9 或 1.27.2 及以上，x/net 至少 v0.60.0."
        runtime_doctor_info "这不是可利用性结论；不会自动重编译、替换二进制、停用协议或重启服务."
    fi
    return "$issue"
}

runtime_doctor_go_build_binary() {
    local label=$1 binary=$2 kind=$3 metadata=""

    case $kind in
        caddy) metadata=$("$binary" build-info 2> /dev/null) || metadata="" ;;
        core) metadata=$("$binary" version 2> /dev/null) || metadata="" ;;
        cloudflared) metadata=$("$binary" --version 2> /dev/null) || metadata="" ;;
        *) return 1 ;;
    esac
    # Do not invoke Go automatically: even "go version -m" can initialize Go
    # telemetry/cache state. Missing native metadata must remain unverified.
    runtime_doctor_go_build_report "$label" "$metadata"
}

runtime_doctor_build_security() {
    local issue=0 binary=""

    if [[ -x ${is_core_bin:-} ]]; then
        runtime_doctor_go_build_binary sing-box "$is_core_bin" core || issue=1
    fi
    if [[ -x ${is_caddy_bin:-} ]]; then
        runtime_doctor_go_build_binary Caddy "$is_caddy_bin" caddy || issue=1
    fi
    if binary=$(command -v cloudflared) && [[ -x $binary ]]; then
        runtime_doctor_go_build_binary cloudflared "$binary" cloudflared || issue=1
    fi
    runtime_doctor_info "编译依赖检查仅覆盖 GO-2026-6603/GO-2026-6617；可在隔离开发机用 go version -m <二进制副本> 补查，不需要在服务器安装 Go，doctor 也不自动调用 Go."
    return "$issue"
}
