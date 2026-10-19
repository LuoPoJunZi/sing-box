#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
. src/lib/version.sh
. src/core/runtime/doctor/build.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[build-security] $*" >&2
    exit 1
}
runtime_doctor_ok() { printf 'OK:%s\n' "$*"; }
runtime_doctor_warn() { printf 'WARN:%s\n' "$*"; }
runtime_doctor_info() { printf 'INFO:%s\n' "$*"; }

assert_warning() {
    local metadata=$1 expected=$2 output
    if output=$(runtime_doctor_go_build_report fixture "$metadata"); then
        fail "unsafe/unverified metadata passed: $expected"
    fi
    [[ $output == *"$expected"* ]] || fail "warning missing: $expected"
    [[ $output == *'不会自动重编译'* ]] || fail 'mutating recovery implied'
}

# Standard Caddy/go version -m formats, CRLF and paths containing spaces.
safe=$'go\tgo1.26.9\ndep\tgolang.org/x/net\tv0.60.0\th1:test'
output=$(runtime_doctor_go_build_report Caddy "$safe") || fail 'fixed build rejected'
[[ $output != *WARN:* && $output == *'修复基线'* ]] || fail 'fixed build output incorrect'
output=$(runtime_doctor_go_build_report core $'/tmp/path with spaces/core: go1.27.2\r\n\tdep\tgolang.org/x/net\tv0.61.0\th1:test\r\n') || fail 'Go embedded metadata/CRLF failed'
for version in go1.26.10 go1.27.3 go1.28.0; do
    runtime_doctor_go_build_report fixture "${safe/go1.26.9/$version}" > /dev/null || fail "fixed branch rejected: $version"
done
for version in go1.25.5 go1.26.8 go1.27.0 go1.27.1; do
    assert_warning "${safe/go1.26.9/$version}" '受影响版本范围'
done
for version in go1.27rc2 devel go1.26.9-custom unknown; do
    assert_warning "${safe/go1.26.9/$version}" '未核实'
done
assert_warning "${safe/v0.60.0/v0.59.0}" '低于'
assert_warning "${safe/v0.60.0/v0.60.0-20261001-test}" '未核实'
assert_warning '' '未核实'
assert_warning $'Environment: go1.26.8 linux/amd64\nTags: test' '受影响版本范围'
assert_warning $'Environment: go1.26.9 linux/amd64' 'x/net: 未核实'
assert_warning "$safe"$'\ngo\tgo1.26.8' 'Go 编译版本: 未核实'
assert_warning "$safe"$'\ndep\tgolang.org/x/net\tv0.61.0' 'x/net: 未核实'

# Effective replacement version, not the requested dependency version, wins.
assert_warning "$safe"$'\t\n=>\tgolang.org/x/net\tv0.59.0\th1:test' '低于'
assert_warning "$safe"$'\n=>\t../local-net\t(devel)' '未核实'
assert_warning "$safe"$'\n=>\texample.com/fork/net\tv0.99.0' '未核实'
runtime_doctor_go_build_report fixture "$safe"$'\n=>\tgolang.org/x/net\tv0.61.0\th1:test' > /dev/null || fail 'reviewed replacement rejected'

# Read-only native probes. Go/toolchain commands must never be invoked.
native_status=0
native_metadata=$safe
native() {
    case $1 in build-info | version | --version)
        printf '%s\n' "$native_metadata"
        return "$native_status"
        ;;
    *) fail 'unexpected binary invocation' ;; esac
}
forbidden() {
    printf '%s\n' "$*" > "$tmp_dir/unexpected-command"
    return 1
}
go() { forbidden go; }
curl() { forbidden curl; }
wget() { forbidden wget; }
systemctl() { forbidden systemctl; }
install() { forbidden install; }
runtime_doctor_go_build_binary fixture native caddy > /dev/null || fail 'native Caddy fallback failed'
native_status=1
if output=$(runtime_doctor_go_build_binary fixture native caddy); then fail 'failed native output was trusted'; fi
[[ $output == *'未核实'* ]] || fail 'failed native probe not reported'
native_status=0
native_metadata=$'Environment: go1.26.8 linux/amd64'
if runtime_doctor_go_build_binary fixture native core > /dev/null; then fail 'old Go core passed'; fi
native_metadata='cloudflared version 2026.10.1'
if runtime_doctor_go_build_binary fixture native cloudflared > /dev/null; then fail 'cloudflared release tag substituted for build data'; fi

native_metadata=$safe
runtime_doctor_go_build_binary fixture native caddy > /dev/null || fail 'native metadata reader failed'

# The doctor entry point delegates build checks independently of version checks.
is_core_bin="$tmp_dir/core with spaces"
is_caddy_bin="$tmp_dir/caddy"
printf '%s\n' '#!/usr/bin/env bash' > "$is_core_bin"
printf '%s\n' '#!/usr/bin/env bash' > "$is_caddy_bin"
chmod +x "$is_core_bin" "$is_caddy_bin"
runtime_doctor_go_build_binary() {
    printf 'CHECK:%s:%s\n' "$1" "$3"
    return 1
}
if output=$(runtime_doctor_build_security); then fail 'aggregate warnings did not propagate'; fi
[[ $output == *'CHECK:sing-box:core'* && $output == *'CHECK:Caddy:caddy'* ]] || fail 'installed components not checked'
[[ $output == *'不需要在服务器安装 Go'* ]] || fail 'Go installation requirement implied'
grep -q 'if ! runtime_doctor_build_security; then' src/core/runtime/doctor/run.sh || fail 'build checks not wired into sb doctor'
[[ ! -e $tmp_dir/unexpected-command ]] || fail "read-only check ran $(< "$tmp_dir/unexpected-command")"
echo '[build-security] ok: ranges, unknowns, replacements and native probes without Go/toolchain writes'
