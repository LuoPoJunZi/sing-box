#!/bin/bash

author="LuoPoJunZi"
# github=https://github.com/LuoPoJunZi/sing-box-ev

# bash fonts colors
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
ui_warn_badge() { ui_warn "[WARN]"; }
ui_err_badge() { ui_error "[ERR]"; }

_red() { ui_error "$@"; }
_blue() { ui_value "$@"; }
_cyan() { ui_brand "$@"; }
_green() { ui_success "$@"; }
_yellow() { ui_warn "$@"; }
_magenta() { ui_style "$magenta" "$@"; }
_red_bg() { ui_danger_badge "$@"; }

is_err=$(ui_err_badge)
is_warn=$(ui_warn_badge)

err() {
    printf '\n%b %s\n\n' "$is_err" "$*"
    exit 1
}

warn() {
    printf '\n%b %s\n\n' "$is_warn" "$*"
}

cmd=
is_arch=

check_environment() {
    [[ $EUID == 0 ]] || err "当前非 ${yellow}ROOT用户.${none}"

    cmd=$(command -v apt-get || command -v yum || command -v zypper)
    [[ $cmd ]] || err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS or SUSE)${none}."

    if ! command -v systemctl > /dev/null 2>&1; then
        err "此系统缺少 ${yellow}(systemctl)${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
    fi

    case $(uname -m) in
        amd64 | x86_64) is_arch=amd64 ;;
        *aarch64* | *armv8*) is_arch=arm64 ;;
        *) err "此脚本仅支持 64 位系统..." ;;
    esac
}

is_core=sing-box
is_core_name=sing-box
is_core_dir="/etc/$is_core"
is_core_bin="$is_core_dir/bin/$is_core"
is_core_repo="SagerNet/$is_core"
is_conf_dir="$is_core_dir/conf"
is_log_dir="/var/log/$is_core"
is_sh_bin="/usr/local/bin/$is_core"
is_sh_dir="$is_core_dir/sh"

# ==================================================================
# 适配新仓库地址
# ==================================================================
is_sh_repo="LuoPoJunZi/sing-box-ev"

is_pkg=(wget tar curl)
# Used by functions loaded dynamically near the end of the installer.
# shellcheck disable=SC2034
is_config_json="$is_core_dir/config.json"

tmpdir=
tmpcore=
tmpsh=
tmpjq=
is_core_ok=
is_sh_ok=
is_jq_ok=
is_pkg_ok=
is_fail=

init_tmp_paths() {
    tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'tmp-XXXXXX')
    tmpcore="$tmpdir/tmpcore"
    tmpsh="$tmpdir/tmpsh"
    tmpjq="$tmpdir/tmpjq"
    is_core_ok="$tmpdir/is_core_ok"
    is_sh_ok="$tmpdir/is_sh_ok"
    is_jq_ok="$tmpdir/is_jq_ok"
    is_pkg_ok="$tmpdir/is_pkg_ok"
}

cleanup_tmpdir() {
    if [[ ${tmpdir:-} && -d $tmpdir ]]; then
        rm -rf -- "$tmpdir"
    fi
}

load() {
    # shellcheck source=/dev/null
    . "$is_sh_dir/src/$1"
}

_wget() {
    wget "$@"
}

msg() {
    local color=""
    case $1 in
        warn) color=$yellow ;;
        err) color=$red ;;
        ok) color=$green ;;
    esac
    printf '%b\n' "${color}$(date +'%T')${none}) ${2}"
}

show_help() {
    local exit_code=${1:-0}
    printf '%s\n' "Usage: $0 [-f xxx | -l | -v xxx | -h]"
    printf '%s\n' "  -f, --core-file <path>          自定义 $is_core_name 文件路径"
    printf '%s\n' "  -l, --local-install             本地获取安装脚本"
    printf '%s\n' "  -v, --core-version <ver>        自定义 $is_core_name 版本"
    printf '%s\n\n' "  -h, --help                      显示此帮助界面"
    exit "$exit_code"
}

install_pkg() {
    local package_name
    local missing_packages=()

    for package_name in "$@"; do
        if ! command -v "$package_name" > /dev/null 2>&1; then
            missing_packages+=("$package_name")
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        : > "$is_pkg_ok"
        return
    fi

    msg warn "安装依赖包 > ${missing_packages[*]}"
    if "$cmd" install -y "${missing_packages[@]}" &> /dev/null; then
        : > "$is_pkg_ok"
        return
    fi

    if [[ $cmd == *yum ]]; then
        yum install epel-release -y &> /dev/null
    fi
    if [[ $cmd == *zypper ]]; then
        "$cmd" --non-interactive refresh &> /dev/null
    else
        "$cmd" update -y &> /dev/null
    fi
    if "$cmd" install -y "${missing_packages[@]}" &> /dev/null; then
        : > "$is_pkg_ok"
    fi
}

installer_sha256_file() {
    sha256sum "$1" | awk '{print tolower($1)}'
}

installer_verify_sha256() {
    local file=$1 expected=${2#sha256:} actual=""

    [[ $expected =~ ^[0-9a-fA-F]{64}$ ]] || return 1
    actual=$(installer_sha256_file "$file") || return 1
    [[ $actual == "${expected,,}" ]]
}

installer_download_verified() {
    local url=$1 expected=$2 destination=$3 name=$4

    [[ $url == https://* ]] || return 1
    msg warn "下载并校验 ${name} > ${url}"
    if ! _wget -t 5 -q -T 60 "$url" -O "$destination"; then
        rm -f -- "$destination"
        return 1
    fi
    if ! installer_verify_sha256 "$destination" "$expected"; then
        rm -f -- "$destination"
        msg err "${name} 的 SHA-256 校验失败，已拒绝使用该文件."
        return 1
    fi
}

installer_release_download() {
    local repo=$1 tag=$2 asset=$3 destination=$4 name=$5
    local endpoint metadata fields url digest

    if [[ $tag != latest && ! $tag =~ ^v?[0-9A-Za-z][0-9A-Za-z._-]*$ ]]; then
        return 1
    fi
    if [[ $tag == latest ]]; then
        endpoint="https://api.github.com/repos/${repo}/releases/latest"
    else
        endpoint="https://api.github.com/repos/${repo}/releases/tags/${tag}"
    fi
    metadata="$tmpdir/release-${RANDOM}.json"
    if ! _wget -q -t 5 -T 30 "$endpoint" -O "$metadata"; then
        rm -f -- "$metadata"
        return 1
    fi
    if ! "$json_tool" -e '.tag_name and (.assets | type == "array")' "$metadata" > /dev/null 2>&1; then
        rm -f -- "$metadata"
        return 1
    fi
    fields=$("$json_tool" -r --arg name "$asset" '
        first(.assets[] | select(.name == $name)) |
        select(.browser_download_url != null) |
        [.browser_download_url, (.digest // "")] | @tsv
    ' "$metadata")
    rm -f -- "$metadata"
    [[ $fields ]] || return 1
    IFS=$'\t' read -r url digest <<< "$fields"
    [[ $digest == sha256:* ]] || return 1
    installer_download_verified "$url" "$digest" "$destination" "$name"
}

installer_tar_paths_safe() {
    local archive=$1 entry normalized

    tar tzf "$archive" > /dev/null 2>&1 || return 1
    while IFS= read -r entry; do
        normalized=${entry#./}
        if [[ ! $normalized || $normalized == '.' ]]; then
            continue
        fi
        if [[ $normalized == /* || $normalized == '..' || $normalized == ../* || $normalized == */../* ]]; then
            return 1
        fi
    done < <(tar tzf "$archive")
}

download() {
    local name="" tmpfile="" is_ok="" expected=""
    local repo="" tag="" asset=""

    case $1 in
        jq)
            name=jq
            tmpfile=$tmpjq
            is_ok=$is_jq_ok
            case $is_arch in
                amd64) expected=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f ;;
                arm64) expected=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309 ;;
            esac
            if installer_download_verified "https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-${is_arch}" "$expected" "$tmpfile" "$name"; then
                chmod +x "$tmpfile"
                if "$tmpfile" --version > /dev/null 2>&1; then
                    mv -f -- "$tmpfile" "$is_ok"
                fi
            fi
            return
            ;;
        core)
            name=$is_core_name
            tmpfile=$tmpcore
            is_ok=$is_core_ok
            repo=$is_core_repo
            tag=${is_core_ver:-latest}
            if [[ $tag == latest ]]; then
                local core_metadata="$tmpdir/core-release.json"
                if ! _wget -q -t 5 -T 30 "https://api.github.com/repos/${repo}/releases/latest" -O "$core_metadata"; then
                    return
                fi
                is_core_ver=$("$json_tool" -r '.tag_name // empty' "$core_metadata")
                rm -f -- "$core_metadata"
                tag=$is_core_ver
            fi
            [[ $tag =~ ^v?[0-9A-Za-z][0-9A-Za-z._-]*$ ]] || return
            asset="${is_core}-${tag#v}-linux-${is_arch}.tar.gz"
            ;;
        sh)
            name="$is_core_name 脚本"
            tmpfile=$tmpsh
            is_ok=$is_sh_ok
            repo=$is_sh_repo
            tag=latest
            asset=code.tar.gz
            ;;
    esac

    if [[ $repo && $tag && $asset ]] && installer_release_download "$repo" "$tag" "$asset" "$tmpfile" "$name"; then
        mv -f -- "$tmpfile" "$is_ok"
    fi
}

get_ip() {
    ip=$(curl -s4m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    [[ -z $ip ]] && ip=$(curl -s6m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
}

check_status() {
    if [[ ! -f $is_pkg_ok ]]; then
        msg err "安装依赖包失败"
        is_fail=1
    fi
    if [[ ! -f $is_core_ok ]]; then
        msg err "下载 ${is_core_name} 失败"
        is_fail=1
    fi
    if [[ ! -f $is_sh_ok ]]; then
        msg err "下载脚本失败"
        is_fail=1
    fi
    if [[ ! -f $is_jq_ok ]]; then
        msg err "下载 jq 失败"
        is_fail=1
    fi
    [[ $is_fail ]] && exit_and_del_tmpdir
}

pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f | --core-file)
                [[ $# -ge 2 && -n $2 ]] || err "$1 缺少文件路径."
                is_core_file=$2
                shift 2
                ;;
            -l | --local-install)
                local_install=1
                shift
                ;;
            -v | --core-version)
                [[ $# -ge 2 && -n $2 ]] || err "$1 缺少版本号."
                is_core_ver="v${2#v}"
                [[ $is_core_ver =~ ^v[0-9A-Za-z][0-9A-Za-z._-]*$ ]] || err "核心版本号包含不安全字符."
                shift 2
                ;;
            -h | --help) show_help ;;
            *)
                warn "($*) 为未知参数..."
                show_help 1
                ;;
        esac
    done
}

exit_and_del_tmpdir() {
    cleanup_tmpdir
    if [[ ! ${1:-} ]]; then
        msg err "安装过程出现错误..."
        printf '%s\n' "反馈问题) https://github.com/${is_sh_repo}/issues"
        exit 1
    fi
    exit
}

main() {
    [[ $# -gt 0 ]] && pass_args "$@"
    check_environment
    init_tmp_paths
    trap cleanup_tmpdir EXIT

    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "检测到脚本已安装, 如需重装请使用${green} ${is_core} reinstall ${none}命令."
    }

    clear
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"

    mkdir -p "$tmpdir"
    [[ ${is_core_file:-} ]] && cp -f -- "$is_core_file" "$is_core_ok"
    [[ ${local_install:-} ]] && : > "$is_sh_ok"

    if ! timedatectl set-ntp true &> /dev/null; then
        # Used by dynamically sourced node creation code.
        # shellcheck disable=SC2034
        is_ntp_on=1
    fi

    install_pkg "${is_pkg[@]}"
    if [[ ! -f $is_pkg_ok ]]; then
        check_status
    fi
    command -v sha256sum > /dev/null 2>&1 || err "当前系统缺少 sha256sum，无法安全校验下载文件."

    if command -v jq > /dev/null 2>&1; then
        json_tool=$(command -v jq)
        : > "$is_jq_ok"
    else
        jq_not_found=1
        download jq
        if [[ -f $is_jq_ok ]]; then
            json_tool=$is_jq_ok
        fi
    fi

    [[ $json_tool ]] || err "jq 不可用，无法校验 GitHub Release 元数据."
    [[ ! ${is_core_file:-} ]] && download core
    [[ ! ${local_install:-} ]] && download sh
    get_ip
    check_status

    if [[ ${is_core_file:-} ]]; then
        mkdir -p "$tmpdir/testzip"
        if ! installer_tar_paths_safe "$is_core_ok" || ! tar zxf "$is_core_ok" --strip-components 1 -C "$tmpdir/testzip" &> /dev/null || [[ ! -f $tmpdir/testzip/$is_core ]]; then
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        fi
    fi

    if [[ ! ${ip:-} ]]; then
        msg err "获取服务器 IP 失败."
        exit_and_del_tmpdir
    fi

    mkdir -p "$is_sh_dir"
    cat > "$is_sh_dir/.install_manifest" << EOF
dir|$is_core_dir
dir|$is_sh_dir
dir|$is_conf_dir
dir|$is_log_dir
file|$is_sh_bin
file|${is_sh_bin/$is_core/sb}
file|/lib/systemd/system/$is_core.service
line|/root/.bashrc|alias sb=$is_sh_bin
line|/root/.bashrc|alias $is_core=$is_sh_bin
cron|sing-box update
cron|/var/log/sing-box
EOF
    if [[ ${local_install:-} ]]; then
        cp -rf -- "$PWD"/* "$is_sh_dir"
    else
        installer_tar_paths_safe "$is_sh_ok" || err "脚本发布包包含不安全路径."
        tar zxf "$is_sh_ok" --strip-components=1 -C "$is_sh_dir"
    fi

    mkdir -p "$is_core_dir/bin"
    if [[ ${is_core_file:-} ]]; then
        cp -rf -- "$tmpdir/testzip"/* "$is_core_dir/bin"
    else
        installer_tar_paths_safe "$is_core_ok" || err "${is_core_name} 发布包包含不安全路径."
        tar zxf "$is_core_ok" --strip-components 1 -C "$is_core_dir/bin"
    fi

    printf '%s\n' "alias sb=$is_sh_bin" >> /root/.bashrc
    printf '%s\n' "alias $is_core=$is_sh_bin" >> /root/.bashrc

    ln -sf -- "$is_sh_dir/$is_core.sh" "$is_sh_bin"
    ln -sf -- "$is_sh_dir/$is_core.sh" "${is_sh_bin/$is_core/sb}"

    if [[ ${jq_not_found:-} ]]; then
        mv -f -- "$is_jq_ok" /usr/bin/jq
        echo "file|/usr/bin/jq" >> "$is_sh_dir/.install_manifest"
        chmod +x /usr/bin/jq
    fi

    chmod +x "$is_core_bin" "$is_sh_bin" "${is_sh_bin/$is_core/sb}"

    mkdir -p "$is_log_dir"
    msg ok "生成配置文件..."

    # 这里我们不再通过 load systemd.sh 来安装，因为我们重构了目录。
    # 我们直接从 utils.sh 里加载。
    # 由于是初次安装环境还未配置，我们临时加载 utils.sh
    # shellcheck source=/dev/null
    . "$is_sh_dir/src/utils.sh"
    # Used by dynamically sourced node modules.
    # shellcheck disable=SC2034
    is_new_install=1
    install_service "$is_core" &> /dev/null

    mkdir -p "$is_conf_dir"

    # 模拟环境以供 add reality 运行
    # shellcheck source=/dev/null
    . "$is_sh_dir/src/init.sh"

    # 强制在静默模式下创建节点，防止备注卡死
    # shellcheck disable=SC2034
    is_main_start=
    add reality

    exit_and_del_tmpdir ok
}

main "$@"
