#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
if [[ ${1:-} == --help ]]; then
    echo 'Opt-in verified Caddy/core/cloudflared checks; loopback only, no host services.'
    echo 'Requires Node >= 18, jq, curl, tar. Optional verified CADDY_BIN, SING_BOX_CORE_BIN, CLOUDFLARED_BIN.'
    echo 'UPSTREAM_REALITY_REQUIRE_FIXED=1 turns the known upstream fallback failure into a hard failure.'
    exit 0
fi
[[ $# -eq 0 ]] || {
    echo 'Unknown option; use --help' >&2
    exit 1
}
for cmd in node jq curl tar; do command -v "$cmd" > /dev/null || {
    echo "Missing $cmd" >&2
    exit 1
}; done
. src/lib/version.sh
. src/lib/download.sh
. src/core/utils/download.sh
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
warn() { printf '%s\n' "$*" >&2; }
# Adapt the shared verified downloader without adding wget to this opt-in test.
_wget() {
    local url='' output='' timeout=60
    while (($#)); do
        case $1 in
            -q) shift ;;
            -t) shift 2 ;;
            -T)
                timeout=$2
                shift 2
                ;;
            -O)
                output=$2
                shift 2
                ;;
            https://*)
                url=$1
                shift
                ;;
            *) return 1 ;;
        esac
    done
    [[ $url && $output ]] || return 1
    curl --fail --silent --show-error --location --retry 3 --max-time "$timeout" "$url" --output "$output"
}
case $(uname -m) in
    x86_64 | amd64) arch=amd64 ;;
    arm64 | aarch64) arch=arm64 ;;
    *)
        echo 'Unsupported test architecture' >&2
        exit 1
        ;;
esac
case $(uname -s) in
    Linux) platform=linux ;;
    *)
        [[ ${CADDY_BIN:-} && ${SING_BOX_CORE_BIN:-} && ${CLOUDFLARED_BIN:-} ]] || {
            echo 'Outside Linux, provide all three verified local binaries.' >&2
            exit 1
        }
        platform=local
        ;;
esac
if [[ -z ${CADDY_BIN:-} ]]; then
    mkdir "$tmp_dir/caddy"
    caddy_version=$(caddy_recommended_stable_version)
    download_verified_release_asset caddyserver/caddy "v$caddy_version" "caddy_${caddy_version}_${platform}_${arch}.tar.gz" "$tmp_dir/caddy.tar.gz"
    download_tar_paths_safe "$tmp_dir/caddy.tar.gz"
    tar zxf "$tmp_dir/caddy.tar.gz" -C "$tmp_dir/caddy"
    CADDY_BIN="$tmp_dir/caddy/caddy"
fi
if [[ -z ${SING_BOX_CORE_BIN:-} ]]; then
    mkdir "$tmp_dir/core"
    core_version=$(sing_box_recommended_stable_version)
    download_verified_release_asset SagerNet/sing-box "v$core_version" "sing-box-${core_version}-${platform}-${arch}.tar.gz" "$tmp_dir/core.tar.gz"
    download_tar_paths_safe "$tmp_dir/core.tar.gz"
    tar zxf "$tmp_dir/core.tar.gz" --strip-components 1 -C "$tmp_dir/core"
    SING_BOX_CORE_BIN="$tmp_dir/core/sing-box"
fi
if [[ -z ${CLOUDFLARED_BIN:-} ]]; then
    download_verified_release_asset cloudflare/cloudflared "$(cloudflared_recommended_stable_version)" "cloudflared-${platform}-${arch}" "$tmp_dir/cloudflared"
    CLOUDFLARED_BIN="$tmp_dir/cloudflared"
fi
for binary in "$CADDY_BIN" "$SING_BOX_CORE_BIN" "$CLOUDFLARED_BIN"; do
    [[ -f $binary ]] || {
        echo "Missing binary: $binary" >&2
        exit 1
    }
    [[ $platform == local ]] || chmod +x "$binary"
done
actual=$("$CADDY_BIN" version | awk 'NR==1 {print $1}')
[[ ${actual%$'\r'} == "v$(caddy_recommended_stable_version)" ]]
actual=$("$SING_BOX_CORE_BIN" version | awk 'NR==1 {print $3}')
[[ ${actual%$'\r'} == "$(sing_box_recommended_stable_version)" ]]
actual=$("$CLOUDFLARED_BIN" --version | awk 'NR==1 {print $3}')
[[ ${actual%$'\r'} == "$(cloudflared_recommended_stable_version)" ]]
# The edge protocol flag is hidden from help in some official builds; parse it
# explicitly without running a tunnel or requiring an account/token.
"$CLOUDFLARED_BIN" tunnel --protocol http2 run --help > "$tmp_dir/tunnel-help"
echo '[upstream-runtime] cloudflared version/protocol CLI passed (no edge connection or QUIC E2E claim)'

# Generate the actual production Reality shape; only loopback addresses/ports
# are substituted by the runtime fixture. No production keys/configs are read.
(
    # Runtime modules use optional shared globals; nounset is not their API.
    set +u
    . src/core/env/defaults.sh
    . src/core/node/protocol.sh
    . src/core/node/build.sh
    . tests/fixtures/node-context.sh
    get() { :; }
    get_reality_short_id() { :; }
    reality_private_key=$("$SING_BOX_CORE_BIN" generate reality-keypair | awk '$1=="PrivateKey:" {print $2}') || exit 1
    reality_private_key=${reality_private_key%$'\r'}
    [[ $reality_private_key ]] || exit 1
    fixture_node_context VLESS-REALITY
    node_prepare_protocol VLESS-REALITY || exit 1
    is_listen=127.0.0.1
    is_config_name=runtime-test
    node_build_config || exit 1
) > "$tmp_dir/reality.json"
export CADDY_BIN SING_BOX_CORE_BIN CLOUDFLARED_BIN
UPSTREAM_TEST_DIR=$tmp_dir
if [[ ${OSTYPE:-} == msys* ]]; then
    CADDY_BIN=$(cygpath -w "$CADDY_BIN")
    SING_BOX_CORE_BIN=$(cygpath -w "$SING_BOX_CORE_BIN")
    CLOUDFLARED_BIN=$(cygpath -w "$CLOUDFLARED_BIN")
    UPSTREAM_TEST_DIR=$(cygpath -w "$tmp_dir")
fi
export UPSTREAM_TEST_DIR
node tests/fixtures/upstream-runtime.mjs
