#!/bin/bash

query_show_all_nodes() {
    is_dont_auto_exit=1
    is_show_all=1
    clear
    ui_hr
    ui_title "              Sing-box-EV 节点配置总览"
    ui_hr
    echo

    local config_count=0 url_count=0
    local conf_files=()
    mapfile -t conf_files < <(list_conf_json_names '.json$')
    for v in "${conf_files[@]}"; do
        ((config_count++))
        unset is_protocol port uuid password net is_url custom_remark is_json_str
        get info "$v" > /dev/null 2>&1
        info "$v"
        if [[ $is_url ]]; then ((url_count++)); fi
    done

    if [[ $config_count -eq 0 ]]; then
        echo -e " $(ui_error "目前没有找到任何节点配置，请先添加配置。")\n"
    elif [[ $url_count -eq 0 ]]; then
        echo -e " $(ui_error "未生成可分享的代理节点链接；如上方提示指纹缺失，请先修复。")\n"
    else
        echo -e "\n $(ui_success "共为您列出 $url_count 个节点链接，请直接复制上方链接使用。")\n"
    fi

    is_show_all=
    is_dont_auto_exit=
    pause
}

query_url_qr() {
    is_dont_show_info=1
    info "$2"
    if [[ $is_url ]]; then
        if [[ $1 == 'url' ]]; then
            msg "\n------------- $is_config_name & URL 链接 -------------"
            msg "\n$(ui_link "$is_url")\n"
            if [[ $is_tls_pin_profile ]]; then
                query_tls_pin_print_snippet "$is_tls_pin_profile" "$is_tls_pin_server_name"
            fi
            footer_msg
        else
            link="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$(query_uri_encode "$is_url")"
            msg "\n------------- $is_config_name & QR code 二维码 -------------"
            msg
            if [[ $(type -P qrencode) ]]; then
                qrencode -t ANSI "${is_url}"
            else
                msg "请安装 qrencode: $(_green "$cmd update -y; $cmd install qrencode -y")"
            fi
            msg "\n如果终端无法正常显示二维码, 请复制以下链接到浏览器打开生成:"
            msg "\n$(ui_link "$link")\n"
            footer_msg
        fi
    else
        if [[ $1 == 'url' ]]; then err "($is_config_name) ${is_url_error:-无法生成 URL 链接.}"; else err "($is_config_name) ${is_url_error:-无法生成 QR code 二维码.}"; fi
    fi
}
