#!/bin/bash

# Only query the running kernel's package. Installed packages and uname alone
# cannot prove vendor backports, Livepatch state or the host kernel of a container.
runtime_doctor_kernel_package() {
    local release=$1 package_info=""

    [[ $release =~ ^[[:alnum:]][[:alnum:].+_-]*$ ]] || return 1
    if command -v dpkg-query > /dev/null 2>&1; then
        if package_info=$(dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n' "linux-image-$release" 2> /dev/null); then
            package_info=$(awk -F '\t' '$1 ~ /^ii / && $2 != "" && $3 != "" {print $2 " " $3}' <<< "$package_info")
        else
            package_info=""
        fi
    elif command -v rpm > /dev/null 2>&1; then
        if ! package_info=$(rpm -q --whatprovides "kernel-uname-r = $release" --qf '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' 2> /dev/null); then
            package_info=""
        fi
    fi
    [[ $package_info ]] || return 1
    printf '%s\n' "$package_info"
}

runtime_doctor_kernel_security() {
    local os_release=${1:-/etc/os-release} reboot_marker=${2:-/var/run/reboot-required}
    local platform="" release="" os_id="" package_info="" advisory=""

    platform=$(uname -s 2> /dev/null) || platform=""
    if [[ $platform && $platform != Linux ]]; then
        runtime_doctor_info "Linux 内核 CVE-2026-98432: 当前为 $platform，未核查 Linux 宿主机"
        return 0
    fi

    release=$(uname -r 2> /dev/null) || release=""
    if [[ -r $os_release ]]; then
        # Do not source os-release: diagnosis never executes file contents.
        os_id=$(awk -F= '$1 == "ID" {v=substr($0,4); gsub(/^["\047]|["\047]\r?$/, "", v); sub(/\r$/, "", v); print v; exit}' "$os_release" 2> /dev/null)
    fi
    runtime_doctor_info "运行内核: ${release:-unknown}；发行版: ${os_id:-unknown}"
    if [[ $platform == Linux && $release ]] && package_info=$(runtime_doctor_kernel_package "$release"); then
        runtime_doctor_info "运行内核对应的已安装包: $package_info（不代表补丁已生效）"
    else
        runtime_doctor_info "运行内核对应包: 未核实；自定义内核/容器需向内核提供方或宿主机核查"
    fi
    case $os_id in
        ubuntu) advisory='https://ubuntu.com/security/CVE-2026-98432' ;;
        debian) advisory='https://security-tracker.debian.org/tracker/CVE-2026-98432' ;;
        rhel | centos | rocky | almalinux | fedora | ol)
            advisory='https://access.redhat.com/security/vulnerabilities/RHSB-2026-016'
            ;;
        *) advisory='https://www.cve.org/CVERecord?id=CVE-2026-98432' ;;
    esac
    runtime_doctor_warn "CVE-2026-98432: Linux IPv4 TCP 内核漏洞，补丁状态未核实；需核对发行版回补及正在运行的内核/Livepatch，不能只比较 uname 版本"
    runtime_doctor_info "公告: $advisory"
    if [[ -f $reboot_marker ]]; then
        runtime_doctor_info "系统报告待重启；此标记不证明内核补丁已生效，缺少标记也不代表安全"
    fi
    runtime_doctor_info "仅禁用 MPTCP 不能完整缓解；这里只读查询，不更新/重启内核，不修改 sysctl、防火墙或业务服务"
    return 1
}
