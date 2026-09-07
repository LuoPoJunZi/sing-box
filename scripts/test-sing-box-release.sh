#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

. src/lib/version.sh

compat_version="${SING_BOX_COMPAT_VERSION:-$(sing_box_recommended_stable_version)}"
compat_tag="v${compat_version#v}"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

fail() {
    echo "[sing-box-release] $*"
    exit 1
}

warn() {
    echo "[sing-box-release] $*" >&2
}

_wget() {
    wget "$@"
}

. src/lib/download.sh
. src/core/utils/download.sh
. src/core/utils/dns.sh

case $(uname -m) in
    amd64 | x86_64) compat_arch=amd64 ;;
    aarch64 | arm64) compat_arch=arm64 ;;
    *) fail "unsupported test architecture: $(uname -m)" ;;
esac

if [[ ${SING_BOX_CORE_BIN:-} ]]; then
    core_binary=$SING_BOX_CORE_BIN
    [[ -x $core_binary ]] || fail "SING_BOX_CORE_BIN is not executable: $core_binary"
else
    asset="sing-box-${compat_version#v}-linux-${compat_arch}.tar.gz"
    archive="$tmp_dir/$asset"
    content_dir="$tmp_dir/core"
    mkdir -p "$content_dir"
    echo "[sing-box-release] download and verify $compat_tag ($compat_arch)"
    download_verified_release_asset SagerNet/sing-box "$compat_tag" "$asset" "$archive" "sing-box $compat_tag" || fail "verified core download failed"
    [[ $download_release_tag == "$compat_tag" ]] || fail "release tag mismatch: $download_release_tag"
    download_tar_paths_safe "$archive" || fail "release archive contains unsafe paths"
    tar zxf "$archive" --strip-components 1 -C "$content_dir" || fail "release archive extraction failed"
    core_binary="$content_dir/sing-box"
    chmod +x "$core_binary"
fi

actual_version=$("$core_binary" version 2> /dev/null | awk 'NR == 1 {print $3}')
[[ $(version_normalize "$actual_version") == "${compat_version#v}" ]] || fail "core version mismatch: $actual_version"

conf_dir="$tmp_dir/conf"
mkdir -p "$conf_dir"

tls_bundle="$tmp_dir/tls.pem"
tls_key="$tmp_dir/tls.key"
tls_cert="$tmp_dir/tls.cer"
"$core_binary" generate tls-keypair example.com -m 30 > "$tls_bundle" 2> /dev/null || fail "TLS test certificate generation failed"
awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' "$tls_bundle" > "$tls_key"
awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$tls_bundle" > "$tls_cert"
[[ -s $tls_key && -s $tls_cert ]] || fail "TLS test certificate output was incomplete"
tls_key_config=$tls_key
tls_cert_config=$tls_cert
if [[ $core_binary == *.exe ]] && command -v cygpath > /dev/null 2>&1; then
    tls_key_config=$(cygpath -w "$tls_key")
    tls_cert_config=$(cygpath -w "$tls_cert")
fi

reality_output=$("$core_binary" generate reality-keypair 2> /dev/null) || fail "Reality key generation failed"
reality_private_key=$(awk '$1 == "PrivateKey:" {print $2}' <<< "$reality_output")
[[ $reality_private_key ]] || fail "Reality private key was not found"

jq -n '
    {
        inbounds: [
            {
                tag: "socks-test",
                type: "socks",
                listen: "127.0.0.1",
                listen_port: 31001,
                users: [{username: "test", password: "test-password"}]
            },
            {
                tag: "shadowsocks-test",
                type: "shadowsocks",
                listen: "127.0.0.1",
                listen_port: 31002,
                method: "aes-128-gcm",
                password: "test-password"
            },
            {
                tag: "vmess-test",
                type: "vmess",
                listen: "127.0.0.1",
                listen_port: 31003,
                users: [{uuid: "00000000-0000-4000-8000-000000000001"}]
            }
        ]
    }
' > "$conf_dir/10-basic.json"

jq -n --arg key "$tls_key_config" --arg cert "$tls_cert_config" '
    {
        inbounds: [
            {
                tag: "hysteria2-test",
                type: "hysteria2",
                listen: "127.0.0.1",
                listen_port: 31004,
                users: [{password: "test-password"}],
                tls: {enabled: true, alpn: ["h3"], key_path: $key, certificate_path: $cert}
            },
            {
                tag: "tuic-test",
                type: "tuic",
                listen: "127.0.0.1",
                listen_port: 31005,
                users: [{uuid: "00000000-0000-4000-8000-000000000002", password: "test-password"}],
                congestion_control: "bbr",
                tls: {enabled: true, alpn: ["h3"], key_path: $key, certificate_path: $cert}
            },
            {
                tag: "trojan-test",
                type: "trojan",
                listen: "127.0.0.1",
                listen_port: 31006,
                users: [{password: "test-password"}],
                tls: {enabled: true, key_path: $key, certificate_path: $cert}
            }
        ]
    }
' > "$conf_dir/20-tls.json"

jq -n --arg private_key "$reality_private_key" '
    {
        inbounds: [
            {
                tag: "reality-test",
                type: "vless",
                listen: "127.0.0.1",
                listen_port: 31007,
                users: [{flow: "xtls-rprx-vision", uuid: "00000000-0000-4000-8000-000000000003"}],
                tls: {
                    enabled: true,
                    server_name: "www.cloudflare.com",
                    reality: {
                        enabled: true,
                        handshake: {server: "www.cloudflare.com", server_port: 443},
                        private_key: $private_key,
                        short_id: ["0123abcd"]
                    }
                }
            }
        ]
    }
' > "$conf_dir/30-reality.json"

legacy_config="$tmp_dir/legacy.json"
modern_config="$tmp_dir/config.json"
cat > "$legacy_config" << 'EOF'
{
  "log": {"level": "warning", "timestamp": true},
  "dns": {
    "servers": [
      {"tag": "dns", "address": "https://1.1.1.1/dns-query", "address_resolver": "local"},
      {"tag": "local", "address": "local"}
    ]
  },
  "route": {"default_domain_resolver": "dns"},
  "outbounds": [{"tag": "direct", "type": "direct"}]
}
EOF

if "$core_binary" check -c "$legacy_config" -C "$conf_dir" > /dev/null 2>&1; then
    fail "sing-box $compat_tag unexpectedly accepted the removed legacy DNS format"
fi

dns_build_modern_config "$legacy_config" "$modern_config" || fail "legacy DNS migration failed"
jq -e '
    .dns.servers[0] == {
        tag: "dns",
        type: "https",
        server: "1.1.1.1",
        domain_resolver: "local",
        path: "/dns-query"
    }
    and .dns.servers[1] == {tag: "local", type: "local"}
' "$modern_config" > /dev/null || fail "migrated DNS structure is not the expected 1.14 format"

"$core_binary" check -c "$modern_config" -C "$conf_dir" > /dev/null 2>&1 || fail "project configurations failed sing-box $compat_tag validation"

echo "[sing-box-release] ok: $compat_tag"
