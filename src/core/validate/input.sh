#!/bin/bash

validate_is_test() {
    case $1 in
        number)
            echo $2 | grep -E '^[1-9][0-9]?+$'
            ;;
        port)
            if [[ $(validate_is_test number $2) ]]; then
                if [[ $2 -le 65535 ]]; then
                    echo ok
                fi
            fi
            ;;
        port_used)
            if [[ $(validate_is_port_used $2) && ! $is_cant_test_port ]]; then
                echo ok
            fi
            ;;
        domain)
            echo $2 | grep -E -i '^\w(\w|\-|\.)?+\.\w+$'
            ;;
        path)
            echo $2 | grep -E -i '^\/\w(\w|\-|\/)?+\w$'
            ;;
        uuid)
            echo $2 | grep -E -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
            ;;
    esac
}

validate_is_port_used() {
    if command -v netstat > /dev/null 2>&1; then
        if [[ ! $is_used_port ]]; then
            is_used_port="$(netstat -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        fi
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    if command -v ss > /dev/null 2>&1; then
        if [[ ! $is_used_port ]]; then
            is_used_port="$(ss -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        fi
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    is_cant_test_port=1
    msg "$is_warn 无法检测端口是否可用."
    msg "请执行: $(_yellow "${cmd} update -y; ${cmd} install net-tools -y") 来修复此问题."
}
