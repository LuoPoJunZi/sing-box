#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/core/runtime/doctor/kernel.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[kernel-security] $*" >&2
    exit 1
}
runtime_doctor_info() { printf 'INFO:%s\n' "$*"; }
runtime_doctor_warn() { printf 'WARN:%s\n' "$*"; }
runtime_doctor_ok() { fail 'kernel patch status must not be inferred'; }
fixture_platform=Linux
fixture_release=6.8.0-100-generic
backend=dpkg
query_status=0
fixture_package_info=$'ii \tlinux-image-6.8.0-100-generic\t6.8.0-100.100'
uname() { case $1 in -s) printf '%s\n' "$fixture_platform" ;; -r) printf '%s\n' "$fixture_release" ;; *) fail 'unexpected uname invocation' ;; esac }
command() {
    if [[ ${1:-} == -v ]]; then
        case ${2:-} in
            dpkg-query)
                [[ $backend == dpkg ]]
                return
                ;;
            rpm)
                [[ $backend == rpm ]]
                return
                ;;
        esac
    fi
    builtin command "$@"
}
dpkg-query() {
    [[ $# == 3 && $1 == -W && $2 == -f=* && $3 == "linux-image-$fixture_release" ]] || fail 'unsafe dpkg query'
    printf '%s\n' "$*" >> "$tmp_dir/queries"
    printf '%s\n' "$fixture_package_info"
    return "$query_status"
}
rpm() {
    [[ $# == 5 && $1 == -q && $2 == --whatprovides && $3 == "kernel-uname-r = $fixture_release" && $4 == --qf ]] || fail 'unsafe rpm query'
    printf '%s\n' "$*" >> "$tmp_dir/queries"
    printf '%s\n' "$fixture_package_info"
    return "$query_status"
}
forbidden() {
    printf '%s\n' "$*" >> "$tmp_dir/forbidden"
    return 1
}
apt() { forbidden apt; }
apt-get() { forbidden apt-get; }
dnf() { forbidden dnf; }
yum() { forbidden yum; }
curl() { forbidden curl; }
wget() { forbidden wget; }
systemctl() { forbidden systemctl; }
sysctl() { forbidden sysctl; }
iptables() { forbidden iptables; }
nft() { forbidden nft; }
reboot() { forbidden reboot; }

check_warning() {
    if output=$(runtime_doctor_kernel_security "$tmp_dir/os-release" "$tmp_dir/reboot-required"); then
        fail 'Linux patch status silently passed'
    fi
    [[ $output == *'CVE-2026-98432'* && $output == *'补丁状态未核实'* ]] || fail 'missing unverified CVE status'
    [[ $output == *'仅禁用 MPTCP 不能完整缓解'* ]] || fail 'MPTCP-only mitigation implied'
    [[ $output != *OK:* ]] || fail 'patch status inferred from local metadata'
}

printf 'ID="ubuntu"\nNAME="$(touch %s/executed)"\n' "$tmp_dir" > "$tmp_dir/os-release"
check_warning
[[ $output == *'ubuntu.com/security/CVE-2026-98432'* && $output == *'linux-image-6.8.0-100-generic 6.8.0-100.100'* ]] || fail 'Ubuntu package/advisory not reported'
[[ ! -e $tmp_dir/executed && $output != *'待重启'* ]] || fail 'os-release executed or reboot status invented'
touch "$tmp_dir/reboot-required"
check_warning
[[ $output == *'系统报告待重启'* ]] || fail 'reboot marker not reported'

# Even a much newer/custom kernel or an apparently fixed vendor package stays
# unverified: the query is not a vendor security database or Livepatch attestation.
fixture_release=9.99.0-bbr
query_status=1
printf 'ID=debian\n' > "$tmp_dir/os-release"
check_warning
[[ $output == *'对应包: 未核实'* && $output == *'security-tracker.debian.org'* ]] || fail 'custom/container kernel not handled'
query_status=0
fixture_package_info=$'rc \tlinux-image-9.99.0-bbr\t99.0'
check_warning
[[ $output == *'对应包: 未核实'* ]] || fail 'removed dpkg package was treated as installed'

backend=rpm
fixture_release=5.14.0-700.el9.x86_64
fixture_package_info='kernel-core 5.14.0-700.el9.x86_64'
printf "ID='rhel'\r\n" > "$tmp_dir/os-release"
check_warning
[[ $output == *"$fixture_package_info"* && $output == *'RHSB-2026-016'* ]] || fail 'RPM provider/advisory not reported'
query_status=1
check_warning
[[ $output == *'对应包: 未核实'* ]] || fail 'failed rpm query trusted'

backend=none
rm -- "$tmp_dir/os-release"
check_warning
[[ $output == *'发行版: unknown'* && $output == *'cve.org/CVERecord'* ]] || fail 'unknown distribution not handled'
backend=dpkg
queries_before=$(< "$tmp_dir/queries")
fixture_release='-unsafe*'
check_warning
[[ $output == *'对应包: 未核实'* ]] || fail 'unsafe release passed package query'
[[ $(< "$tmp_dir/queries") == "$queries_before" ]] || fail 'unsafe release reached package query'
fixture_platform=''
fixture_release=''
check_warning
[[ $output == *'运行内核: unknown'* ]] || fail 'unknown platform/kernel falsely passed'
fixture_platform=Darwin
output=$(runtime_doctor_kernel_security "$tmp_dir/os-release" "$tmp_dir/reboot-required") || fail 'non-Linux not skipped'
[[ $output == *'未核查 Linux 宿主机'* && $output != *WARN:* ]] || fail 'non-Linux falsely checked'
[[ ! -e $tmp_dir/forbidden ]] || fail 'kernel diagnosis performed network/mutations'
grep -q 'if ! runtime_doctor_kernel_security; then' src/core/runtime/doctor/run.sh || fail 'kernel diagnosis not wired into doctor'
echo '[kernel-security] ok: vendor queries, unknown patch state, containers and no mutations'
