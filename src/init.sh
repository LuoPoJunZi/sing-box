#!/bin/bash
# ==========================================
# sing-box Management Script Environment Initialization
# ==========================================

author="LuoPoJunZi"
is_sh_ver="v26.9.10"
is_sh_repo="LuoPoJunZi/sing-box"

# --- 1. 终端 UI 颜色定义 ---
ui_color_enabled=1
if [[ -n ${NO_COLOR:-} || ${TERM:-} == dumb || ! -t 1 ]]; then
    ui_color_enabled=0
fi

if [[ $ui_color_enabled == 1 ]]; then
    red='\e[31m'
    yellow='\e[33m'
    gray='\e[37m'
    green='\e[32m'
    blue='\e[36m'
    magenta='\e[35m'
    cyan='\e[36m'
    bold='\e[1m'
    underline='\e[4m'
    red_bg='\e[41m'
    none='\e[0m'
else
    red=''
    yellow=''
    gray=''
    green=''
    blue=''
    magenta=''
    cyan=''
    bold=''
    underline=''
    red_bg=''
    none=''
fi

ui_style() {
    local style=$1
    shift
    printf '%b\n' "${style}$*${none}"
}

ui_brand() { ui_style "$cyan" "$@"; }
ui_success() { ui_style "$green" "$@"; }
ui_warn() { ui_style "$yellow" "$@"; }
ui_error() { ui_style "$red" "$@"; }
ui_muted() { ui_style "$gray" "$@"; }
ui_link() { ui_style "${underline}${cyan}" "$@"; }
ui_title() { ui_style "${bold}${cyan}" "$@"; }
ui_key() { ui_style "$green" "$@"; }
ui_value() { ui_style "$blue" "$@"; }
ui_danger_badge() { ui_style "$red_bg" "$@"; }
ui_ok_badge() { ui_success "[OK]"; }
ui_stop_badge() { ui_error "[STOP]"; }
ui_warn_badge() { ui_warn "[WARN]"; }
ui_err_badge() { ui_error "[ERR]"; }

_red() { ui_error "$@"; }
_blue() { ui_value "$@"; }
_cyan() { ui_brand "$@"; }
_green() { ui_success "$@"; }
_yellow() { ui_warn "$@"; }
_magenta() { ui_style "$magenta" "$@"; }
_red_bg() { ui_danger_badge "$@"; }

_rm() { rm -rf "$@"; }
_cp() { cp -rf "$@"; }
_sed() { sed -i "$@"; }
_mkdir() { mkdir -p "$@"; }

is_err=$(ui_err_badge)
is_warn=$(ui_warn_badge)

err() {
    printf '\n%b %s\n\n' "$is_err" "$*"
    [[ $is_dont_auto_exit ]] && return
    exit 1
}

warn() {
    printf '\n%b %s\n\n' "$is_warn" "$*"
}

# --- 2. 核心路径与环境变量 ---
is_core="sing-box"
is_core_name="sing-box"
is_core_dir="/etc/$is_core"
is_core_bin="$is_core_dir/bin/$is_core"
is_core_repo="SagerNet/$is_core"
is_conf_dir="$is_core_dir/conf"
is_log_dir="/var/log/$is_core"
is_sh_bin="/usr/local/bin/$is_core"
is_sh_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

is_pkg="wget unzip tar qrencode"
is_config_json="$is_core_dir/config.json"

is_caddy_bin="/usr/local/bin/caddy"
is_caddy_dir="/etc/caddy"
is_caddy_repo="caddyserver/caddy"
is_caddyfile="$is_caddy_dir/Caddyfile"
is_caddy_conf="$is_caddy_dir/$author"
is_http_port=80
is_https_port=443

# --- 3. 基础系统工具包装 ---
load() {
    # shellcheck source=/dev/null
    . "$is_sh_dir/src/$1"
}
_wget() { wget "$@"; }
cmd=$(command -v apt-get || command -v yum || command -v zypper || true)

case $(uname -m) in
    amd64 | x86_64) is_arch="amd64" ;;
    *aarch64* | *armv8*) is_arch="arm64" ;;
    *) err "此脚本仅支持 64 位系统..." ;;
esac

# 提前加载超级工具箱，提供基础功能
load utils.sh

# Loading modules never generates certificates or repairs services.
is_tls_cer="$is_core_dir/bin/tls.cer"
is_tls_key="$is_core_dir/bin/tls.key"
load core.sh
case ${1:-} in
    h | help | --help) ;;
    *) runtime_refresh_status ;;
esac
