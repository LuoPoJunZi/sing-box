#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[download-security] $*"
    exit 1
}

warn() { :; }
payload="$tmp_dir/payload"
destination="$tmp_dir/output"
printf '%s\n' 'verified payload' > "$payload"
expected=$(sha256sum "$payload" | awk '{print $1}')

_wget() {
    local output="" previous="" argument

    for argument in "$@"; do
        if [[ $previous == -O ]]; then
            output=$argument
            break
        fi
        previous=$argument
    done
    [[ $output ]] || return 1
    cp -f -- "$payload" "$output"
}

. src/lib/download.sh
. src/core/utils/download.sh

download_verified_url https://example.invalid/file "$expected" "$destination" test
cmp -s "$payload" "$destination" || fail "verified payload was not installed"

bad_expected="0${expected:1}"
[[ $bad_expected != "$expected" ]] || bad_expected="1${expected:1}"
if download_verified_url https://example.invalid/file "$bad_expected" "$destination" test 2> /dev/null; then
    fail "checksum mismatch was accepted"
fi
[[ ! -f ${destination}.part ]] || fail "mismatched temporary file was retained"
cmp -s "$payload" "$destination" || fail "existing verified destination was modified"

metadata="$tmp_dir/release.json"
cat > "$metadata" << EOF
{"tag_name":"v1.0.0","assets":[{"name":"asset.bin","browser_download_url":"https://example.invalid/asset.bin","digest":"sha256:$expected"}]}
EOF
fields=$(github_release_asset_fields "$metadata" asset.bin)
[[ $fields == *"sha256:$expected" ]] || fail "release asset digest was not parsed"
github_release_tag_is_safe v1.2.3-beta.1 || fail "valid release tag was rejected"
if github_release_tag_is_safe '../../escape'; then
    fail "unsafe release tag was accepted"
fi

mkdir -p "$tmp_dir/archive"
cp -f -- "$payload" "$tmp_dir/archive/payload"
tar czf "$tmp_dir/safe.tar.gz" -C "$tmp_dir/archive" .
download_tar_paths_safe "$tmp_dir/safe.tar.gz" || fail "safe archive paths were rejected"
tar czf "$tmp_dir/unsafe.tar.gz" --transform='s#^payload$#../escape#' -C "$tmp_dir/archive" payload
if download_tar_paths_safe "$tmp_dir/unsafe.tar.gz" 2> /dev/null; then
    fail "archive path traversal was accepted"
fi

if grep -R --line-number -- '--no-check-certificate' install.sh src > /dev/null; then
    fail "TLS certificate verification bypass is still present"
fi
grep -q 'jq-1.8.2' install.sh || fail "installer does not pin jq 1.8.2"
grep -q 'asset=code.tar.gz' install.sh || fail "installer does not use the release code asset"

echo "[download-security] ok"
