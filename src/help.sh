#!/bin/bash

show_help() {
    case $1 in
        api | x25519 | tls | run | uuid | version)
            "$is_core_bin" help "$1" "${@:2}"
            ;;
        *)
            [[ $1 ]] && warn "未知选项 '$1'"
            msg "$is_core_name script $is_sh_ver by $author"
            msg "Usage: sb [options]... [args]... "
            msg
            help_info=(
                "基本:"
                "   v, version                                      显示当前版本"
                "   ip                                              返回当前主机的 IP"
                "   pbk                                             同等于 $is_core generate reality-keypair"
                "   get-port                                        返回一个可用的端口\n"
                "一般:"
                "   dry-run <command> [args...]                     预演模式(不执行写入/重启)"
                "   a, add [protocol] [args... | auto]              添加配置 (Reality 支持 --auto-sni)"
                "   c, change [name] [option] [args... | auto]      更改配置"
                "   d, del [name]                                   删除配置"
                "   i, info [name]                                  查看配置"
                "   url [name]                                      URL 信息"
                "   log                                             查看日志\n"
                "更改:"
                "   full [name] [...]                               更改多个参数"
                "   id [name] [uuid | auto]                         更改 UUID"
                "   host [name] [domain]                            更改域名"
                "   port [name] [port | auto]                       更改端口"
                "   passwd [name] [password | auto]                 更改密码"
                "   key [name] [Private key | atuo] [Public key]    更改密钥"
                "   sni [name] [ ip | domain]                       更改 serverName"
                "   web [name] [domain]                             更改伪装网站\n"
                "进阶:"
                "   dns [...]                                       设置 DNS"
                "   domain [list|add|del|test|pick] [...]          管理 Reality 域名池"
                "   import                                          导入 xray/v2ray 脚本配置\n"
                "管理:"
                "   un, uninstall                                   卸载"
                "   u, update [core | sh | caddy] [ver]             更新"
                "   doctor, diag                                    系统诊断 (环境/颜色/依赖/服务/端口/配置/网络/客户端兼容)"
                "   manifest [summary|list|raw]                     查看安装清单"
                "   backup [list|create [reason]]                   配置快照管理"
                "   rollback [snapshot_id]                          回滚到指定快照"
                "   s, status                                       运行状态"
                "   start, stop, restart [caddy]                    启动, 停止, 重启"
                "   t, test                                         测试运行"
                "   reinstall                                       重装脚本\n"
                "测试:"
                "   debug [name]                                    显示一些 debug 信息"
                "   no-auto-tls [...]                               禁止自动配置 TLS 添加节点\n"
                "其他:"
                "   bbr                                             启用 BBR"
                "   h, help                                         显示此帮助界面\n"
            )
            for v in "${help_info[@]}"; do
                msg "$v"
            done
            msg "反馈问题) $(msg_ul https://github.com/${is_sh_repo}/issues) "
            ;;
    esac
}

about() {
    msg
    msg "============== 关于本脚本 =============="
    msg "维护作者: $author (全新架构版)"
    msg "项目 Github: $(msg_ul https://github.com/${is_sh_repo})"
    msg "特别鸣谢: 基于 233boy 原版深度重构与二次开发"
    msg "----------------------------------------"
    msg "$is_core_name 官网: $(msg_ul https://sing-box.sagernet.org/)"
    msg "$is_core_name 核心: $(msg_ul https://github.com/${is_core_repo})"
    msg "========================================"
    msg
}
