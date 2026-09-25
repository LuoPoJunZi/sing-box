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

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

create_script_tree() {
    local root=$1 required

    mkdir -p "$root/src"
    for required in install.sh sing-box.sh src/init.sh src/utils.sh src/core.sh; do
        printf '#!/usr/bin/env bash\n' > "$root/$required"
    done
}

# Source installer helpers without executing the root/systemd installation path.
NO_COLOR=1 TERM=dumb . ./install.sh

create_script_tree "$tmp_dir/root-tree"
tar czf "$tmp_dir/root.tar.gz" -C "$tmp_dir/root-tree" install.sh sing-box.sh src
installer_prepare_script_archive "$tmp_dir/root.tar.gz" "$tmp_dir/root-stage" || fail "root-layout release archive was rejected"
installer_script_tree_valid "$tmp_dir/root-stage/content" || fail "root-layout archive was not normalized"

# Reproduce v26.9.12: stripping a root-layout archive drops top-level scripts and flattens src/.
mkdir -p "$tmp_dir/retry-tree"
tar zxf "$tmp_dir/root.tar.gz" --strip-components=1 -C "$tmp_dir/retry-tree"
[[ ! -f $tmp_dir/retry-tree/sing-box.sh ]] || fail "regression fixture did not reproduce the stripped root script"
cp -a -- "$tmp_dir/root-stage/content/." "$tmp_dir/retry-tree/"
installer_script_tree_valid "$tmp_dir/retry-tree" || fail "retry did not repair the incomplete script tree"

mkdir -p "$tmp_dir/wrapped"
cp -a -- "$tmp_dir/root-tree" "$tmp_dir/wrapped/sing-box"
tar czf "$tmp_dir/wrapped.tar.gz" -C "$tmp_dir/wrapped" sing-box
installer_prepare_script_archive "$tmp_dir/wrapped.tar.gz" "$tmp_dir/wrapped-stage" || fail "wrapped release archive was rejected"
installer_script_tree_valid "$tmp_dir/wrapped-stage/content" || fail "wrapped archive was not normalized"

printf 'private\n' > "$tmp_dir/root-tree/AGENTS.md"
mkdir -p "$tmp_dir/local-install"
installer_copy_local_script_tree "$tmp_dir/root-tree" "$tmp_dir/local-install" || fail "local script tree copy failed"
[[ ! -e $tmp_dir/local-install/AGENTS.md ]] || fail "local-only file leaked into local installation"

create_script_tree "$tmp_dir/broken-tree"
rm -- "$tmp_dir/broken-tree/src/utils.sh"
tar czf "$tmp_dir/broken.tar.gz" -C "$tmp_dir/broken-tree" .
if installer_prepare_script_archive "$tmp_dir/broken.tar.gz" "$tmp_dir/broken-stage"; then
    fail "archive missing src/utils.sh was accepted"
fi

. src/core/utils/download.sh
[[ $(download_script_tree_root "$tmp_dir/root-tree") == "$tmp_dir/root-tree" ]] || fail "runtime updater rejected root layout"
[[ $(download_script_tree_root "$tmp_dir/wrapped") == "$tmp_dir/wrapped/sing-box" ]] || fail "runtime updater rejected wrapped layout"

if grep -q 'tar zxf "$is_sh_ok" --strip-components' install.sh; then
    fail "installer still strips the first script archive path component"
fi

echo "[install-cli] ok"
