#!/bin/bash
# ==========================================
# sing-box Management Script CLI Entrypoint
# ==========================================

# 1. 加载全局环境与核心函数
. /etc/sing-box/sh/src/init.sh

# 2. 路由分发：如果没有附加任何参数，则默认打开主面板 (main)
if [[ -z "$1" ]]; then
    main "main"
else
    # 否则将所有参数原封不动传递给核心处理
    main "$@"
fi
