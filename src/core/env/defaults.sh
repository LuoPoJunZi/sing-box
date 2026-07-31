#!/bin/bash

protocol_list=(
    TUIC
    Trojan
    Hysteria2
    VMess-WS
    VMess-TCP
    VMess-HTTP
    VMess-QUIC
    Shadowsocks
    VMess-H2-TLS
    VMess-WS-TLS
    VLESS-H2-TLS
    VLESS-WS-TLS
    Trojan-H2-TLS
    Trojan-WS-TLS
    VMess-HTTPUpgrade-TLS
    VLESS-HTTPUpgrade-TLS
    Trojan-HTTPUpgrade-TLS
    VLESS-REALITY
    VLESS-HTTP2-REALITY
    AnyTLS
    CFtunnel
    Socks
)

ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
)

info_list=(
    "协议 (protocol)"
    "地址 (address)"
    "端口 (port)"
    "用户ID (id)"
    "传输协议 (network)"
    "伪装类型 (type)"
    "伪装域名 (host)"
    "路径 (path)"
    "传输层安全 (TLS)"
    "应用层协议协商 (Alpn)"
    "密码 (password)"
    "加密方式 (encryption)"
    "链接 (URL)"
    "目标地址 (remote addr)"
    "目标端口 (remote port)"
    "流控 (flow)"
    "SNI (serverName)"
    "指纹 (Fingerprint)"
    "公钥 (Public key)"
    "用户名 (Username)"
    "跳过证书验证 (insecure)"
    "拥塞控制算法 (congestion_control)"
    "Reality Short ID"
)

change_list=(
    "更改协议"
    "更改端口"
    "更改域名"
    "更改路径"
    "更改密码"
    "更改 UUID"
    "更改加密方式"
    "更改目标地址"
    "更改目标端口"
    "更改密钥"
    "更改 SNI (serverName)"
    "更改伪装网站"
    "更改用户名 (Username)"
)

servername_pool=(
    # 格式: domain|weight|region
    # region: us | eu | apac | global
    # 科技大厂优先 + 保留原有域名
    "www.cloudflare.com|12|global"
    "dash.cloudflare.com|10|global"
    "www.microsoft.com|10|us"
    "www.bing.com|9|us"
    "azure.microsoft.com|8|us"
    "www.apple.com|10|global"
    "developer.apple.com|7|global"
    "www.google.com|10|global"
    "www.youtube.com|8|global"
    "www.github.com|8|global"
    "github.com|8|global"
    "docs.github.com|6|global"
    "www.amazon.com|9|us"
    "aws.amazon.com|8|us"
    "www.oracle.com|5|us"
    "www.ibm.com|5|us"
    "www.ebay.com|4|us"
    "www.paypal.com|4|us"
)

servername_list=(
    www.cloudflare.com
    dash.cloudflare.com
    www.microsoft.com
    www.bing.com
    azure.microsoft.com
    www.apple.com
    developer.apple.com
    www.google.com
    www.youtube.com
    www.github.com
    github.com
    docs.github.com
    www.amazon.com
    aws.amazon.com
    www.oracle.com
    www.ibm.com
    www.ebay.com
    www.paypal.com
)

is_random_ss_method=${ss_method_list[$(shuf -i 4-6 -n1)]}
is_random_servername=${servername_list[$((RANDOM % ${#servername_list[@]}))]}
