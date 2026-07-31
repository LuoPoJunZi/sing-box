#!/bin/bash

sub_gen_sub() {
    clear
    ui_hr
    ui_title "                 生成节点订阅链接 (Sub)"
    ui_hr
    msg "🔍 正在扫描本机节点..."

    local all_urls=""
    local config_count=0
    local skipped_count=0
    local conf_files=()
    mapfile -t conf_files < <(list_conf_json_names '.json$')

    for v in "${conf_files[@]}"; do
        unset is_protocol port uuid password net is_url custom_remark is_json_str host path
        is_dont_show_info=1
        get info "$v" > /dev/null 2>&1
        info "$v" > /dev/null 2>&1
        if [[ $is_url ]]; then
            ((config_count++))
            msg "   $config_count. $is_config_name"
            all_urls+="${is_url}\n"
        else
            ((skipped_count++))
        fi
    done

    if [[ $skipped_count -gt 0 ]]; then
        warn "$skipped_count 个配置未生成分享链接（端口转发节点或证书指纹缺失）。"
    fi

    if [[ $config_count -eq 0 ]]; then
        err "目前没有找到任何有效节点，请先添加配置后再生成订阅。"
        return
    fi

    msg "\n⚙️ 正在进行 Base64 编码并生成订阅文件..."
    local sub_base64
    sub_base64=$(echo -ne "$all_urls" | base64 -w 0)

    echo -e "\n------------- $(ui_success "方案A: 剪贴板 Base64 订阅") -------------"
    echo -e "你可以直接复制下方整段乱码，在客户端选择【从剪贴板导入】:\n"
    ui_warn "$sub_base64"
    echo
    echo -e "--------------------------------------------------------"

    if command -v python3 > /dev/null 2>&1; then
        echo -e "\n------------- $(ui_success "方案B: 临时 Web 订阅服务") -------------"
        mkdir -p /tmp/sb_sub
        echo -ne "$sub_base64" > /tmp/sb_sub/sub.txt

        get_ip
        local sub_port=9866

        fuser -k $sub_port/tcp > /dev/null 2>&1
        cd /tmp/sb_sub
        python3 -m http.server $sub_port > /dev/null 2>&1 &
        local py_pid=$!

        msg "✅ 临时订阅 Web 服务已开启！"
        msg "🔗 $(ui_link "http://${ip}:${sub_port}/sub.txt")\n"
        msg "💡 请在客户端【添加订阅】上方链接，并点击【更新订阅】。"

        echo -ne "\n⚠️ 导入完成后，请按 $(_green Enter 回车键) 关闭临时服务并返回主菜单..."
        read -rs -d $'\n'
        kill $py_pid > /dev/null 2>&1
        rm -rf -- /tmp/sb_sub
        msg "\n✅ 临时服务已销毁，绝对安全。"
    else
        msg "\n⚠️ 未检测到 Python3 环境，无法开启方案B临时服务。"
        msg "若需使用链接订阅功能，请先安装: $(_yellow "apt install python3 -y")"
        pause
    fi
    is_dont_show_info=
}
