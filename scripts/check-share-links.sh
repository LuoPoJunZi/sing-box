#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

. src/core/query/uri.sh

fail() {
    echo "[share-links] $*"
    exit 1
}

encoded=$(query_uri_encode 'A B/中文#')
[[ $encoded == 'A%20B%2F%E4%B8%AD%E6%96%87%23' ]] || fail "URI encoding mismatch: $encoded"

encoded=$(query_uri_base64url 'aes-128-gcm:test?')
[[ $encoded == 'YWVzLTEyOC1nY206dGVzdD8' ]] || fail "base64url mismatch: $encoded"

[[ $(query_uri_host_name '[2001:db8::1]') == '2001:db8::1' ]] || fail "IPv6 SNI normalization failed"

query_uri_params_reset
query_uri_param sni example.com
query_uri_param path '/a b'
[[ $(query_uri_query) == '?sni=example.com&path=%2Fa%20b' ]] || fail "query builder mismatch"

grep -q 'query_uri_param pinSHA256' src/core/query/info.sh || fail "Hysteria2 pinSHA256 export missing"
grep -q 'query_uri_param pcs' src/core/query/info.sh || fail "Xray pcs export missing"
grep -q 'pcs:\$pcs' src/core/query/info.sh || fail "VMess pcs export missing"
grep -q 'query_uri_param sid' src/core/query/info.sh || fail "Reality sid export missing"

if grep -Eq 'query_uri_param allowInsecure|query_uri_param allow_insecure|insecure:\"1\"' src/core/query/info.sh; then
    fail "deprecated Xray allowInsecure export remains"
fi

if grep -q '"allowInsecure":' src/core/query/tls_pin.sh; then
    fail "deprecated allowInsecure remains in client snippets"
fi

echo "[share-links] ok"
