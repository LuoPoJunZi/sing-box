#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for command_name in base64 jq openssl; do
    command -v "$command_name" > /dev/null 2>&1 || {
        echo "[share-output] missing command: $command_name"
        exit 1
    }
done

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
export MSYS2_ARG_CONV_EXCL='/CN='
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=tls' -keyout "$tmp_dir/tls.key" -out "$tmp_dir/tls.cer" > /dev/null 2>&1

is_tls_cer="$tmp_dir/tls.cer"
. src/core/query/uri.sh
. src/core/query/tls_pin.sh
. src/core/query/info.sh

fail() {
    echo "[share-output] $*"
    exit 1
}

reset_case() {
    unset host path uuid password ss_method ss_password is_socks_user is_socks_pass
    unset is_short_id is_servername is_public_key net_type is_new_protocol
    unset is_caddy is_no_auto_tls is_show_all is_gen is_dont_auto_exit
    is_dont_show_info=1
    is_config_name="test.json"
    is_addr="203.0.113.10"
    port=443
    is_https_port=443
    custom_remark='测试 节点#1'
}

reset_case
is_protocol=hysteria2
net=hysteria2
password='p@ss word'
query_info
[[ $is_url == hysteria2://p%40ss%20word@203.0.113.10:443/\?* ]] || fail "Hysteria2 URI prefix mismatch"
[[ $is_url == *'pinSHA256='*'&insecure=1'* || $is_url == *'insecure=1&pinSHA256='* ]] || fail "Hysteria2 pin missing"
[[ $is_url == *'#%E6%B5%8B%E8%AF%95%20%E8%8A%82%E7%82%B9%231' ]] || fail "Hysteria2 remark encoding failed"

reset_case
is_protocol=trojan
net=trojan
password='p@ss word'
query_info
[[ $is_url == *'pcs='* ]] || fail "Trojan pcs missing"
[[ $is_url != *'insecure='* && $is_url != *'allowInsecure='* ]] || fail "Trojan still exports deprecated insecure fields"
[[ ${is_info_str[3]} == 'p@ss word' && ${#is_info_str[@]} -eq 7 ]] || fail "Trojan info fields split on whitespace"

reset_case
is_protocol=tuic
net=tuic
uuid='11111111-1111-1111-1111-111111111111'
password='p@ss:word'
query_info
[[ $is_url == tuic://11111111-1111-1111-1111-111111111111%3Ap%40ss%3Aword@* ]] || fail "TUIC userinfo encoding failed"
[[ $is_url == *'insecure=1&pcs='*'&congestion_control=bbr'* ]] || fail "TUIC compatibility fields, pin, or congestion control missing"
[[ $is_url != *'allow_insecure='* && $is_url != *'allowInsecure='* ]] || fail "TUIC exports redundant allowInsecure aliases"

reset_case
is_protocol=vless
net=reality
uuid='11111111-1111-1111-1111-111111111111'
is_servername='www.microsoft.com'
is_public_key='public+/key='
is_short_id='1a2b3c4d'
net_type=tcp
query_info
[[ $is_url == *'security=reality'*'&pbk=public%2B%2Fkey%3D'*'&sid=1a2b3c4d'* ]] || fail "Reality fields missing"

reset_case
is_protocol=vless
net=ws
uuid='11111111-1111-1111-1111-111111111111'
host='proxy.example.com'
path='/ws path'
query_info
[[ $is_url == *'sni=proxy.example.com&host=proxy.example.com&path=%2Fws%20path'* ]] || fail "domain TLS fields missing"
[[ ${is_info_str[6]} == '/ws path' && ${#is_info_str[@]} -eq 8 ]] || fail "domain TLS info fields split on whitespace"

reset_case
is_protocol=vless
net=reality
uuid='11111111-1111-1111-1111-111111111111'
is_servername='www.microsoft.com'
is_public_key='public+/key='
is_short_id='1a2b3c4d'
net_type=http
is_new_protocol=VLESS-HTTP2-REALITY
query_info
[[ ${#is_info_show[@]} -eq 10 && ${#is_info_str[@]} -eq 10 && ${is_info_str[4]} == h2 ]] || fail "Reality-H2 info fields misaligned"

reset_case
is_protocol=shadowsocks
net=ss
ss_method='aes-128-gcm'
ss_password='p@ss:word'
query_info
ss_userinfo=${is_url#ss://}
ss_userinfo=${ss_userinfo%%@*}
[[ $ss_userinfo != *'='* && $ss_userinfo != *'+'* && $ss_userinfo != *'/'* ]] || fail "Shadowsocks userinfo is not base64url"

reset_case
is_protocol=socks
net=socks
is_socks_user='user'
is_socks_pass='p@ss:word'
query_info
socks_userinfo=${is_url#socks://}
socks_userinfo=${socks_userinfo%%@*}
[[ $socks_userinfo != *'='* && $socks_userinfo != *'+'* && $socks_userinfo != *'/'* ]] || fail "SOCKS userinfo is not base64url"

reset_case
is_protocol=vmess
net=quic
uuid='11111111-1111-1111-1111-111111111111'
is_addr='[2001:db8::1]'
query_info
vmess_json=$(printf '%s' "${is_url#vmess://}" | base64 -d)
jq -e '.add == "2001:db8::1" and .tls == "tls" and .sni == "2001:db8::1" and (has("insecure") | not) and (.pcs | test("^[0-9a-f]{64}$"))' <<< "$vmess_json" > /dev/null || fail "VMess-QUIC address or TLS pin fields missing"

reset_case
is_protocol=trojan
net=trojan
password='safe-only'
is_tls_cer="$tmp_dir/missing.cer"
query_info
[[ -z $is_url && $is_url_error == *'无法安全生成分享链接'* ]] || fail "missing pin must fail closed"

msg() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*"; }
ui_style() { printf '%s' "$2"; }
footer_msg() { :; }
is_dont_show_info=
output=$(query_info 2>&1)
[[ $output == *'无法安全生成分享链接'* ]] || fail "sb info must explain missing pin"

echo "[share-output] ok"
