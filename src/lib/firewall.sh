#!/bin/bash

firewall_allow() {
    local target_port=$1
    if [[ -z "$target_port" ]]; then
        return
    fi

    if command -v ufw > /dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow ${target_port}/tcp > /dev/null 2>&1
        ufw allow ${target_port}/udp > /dev/null 2>&1
        managed_record port "$target_port"
        msg "✅ 防火墙 (UFW): 已自动放行端口 ${target_port}"
    elif command -v firewall-cmd > /dev/null 2>&1 && systemctl is-active firewalld | grep -q "^active"; then
        firewall-cmd --add-port=${target_port}/tcp --permanent > /dev/null 2>&1
        firewall-cmd --add-port=${target_port}/udp --permanent > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        managed_record port "$target_port"
        msg "✅ 防火墙 (Firewalld): 已自动放行端口 ${target_port}"
    elif command -v iptables > /dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport ${target_port} -j ACCEPT > /dev/null 2>&1
        iptables -I INPUT -p udp --dport ${target_port} -j ACCEPT > /dev/null 2>&1
        if [[ -f /etc/sysconfig/iptables ]]; then
            service iptables save > /dev/null 2>&1
        fi
        if command -v netfilter-persistent > /dev/null 2>&1; then
            netfilter-persistent save > /dev/null 2>&1
        fi
        managed_record port "$target_port"
        msg "✅ 防火墙 (Iptables): 已尝试放行端口 ${target_port}"
    fi
}
