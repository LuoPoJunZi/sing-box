#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
    echo "[install-cli] $*"
    exit 1
}

help_output=$(NO_COLOR=1 TERM=dumb bash install.sh --help)
[[ $help_output == *'Usage: install.sh'* ]] || fail "help output missing usage"
[[ $help_output != *$'\033'* ]] || fail "help output contains ANSI escapes"

set +e
unknown_output=$(NO_COLOR=1 TERM=dumb bash install.sh --unknown 2>&1)
unknown_status=$?
missing_output=$(NO_COLOR=1 TERM=dumb bash install.sh --core-version 2>&1)
missing_status=$?
unsafe_version_output=$(NO_COLOR=1 TERM=dumb bash install.sh --core-version '../../escape' 2>&1)
unsafe_version_status=$?
set -e

[[ $unknown_status -ne 0 ]] || fail "unknown option must fail"
[[ $unknown_output == *'未知参数'* ]] || fail "unknown option error missing"
[[ $missing_status -ne 0 ]] || fail "missing option value must fail"
[[ $missing_output == *'缺少版本号'* ]] || fail "missing option value error missing"
[[ $unsafe_version_status -ne 0 ]] || fail "unsafe core version must fail"
[[ $unsafe_version_output == *'不安全字符'* ]] || fail "unsafe core version error missing"

echo "[install-cli] ok"
