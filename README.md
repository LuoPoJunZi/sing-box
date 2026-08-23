# Sing-box-EV

中文文档 | [English](./README.en.md)

Sing-box-EV 是一个面向 Linux 服务器的 `sing-box` 管理脚本项目。它提供：

- 一键安装与更新
- TUI 菜单操作
- CLI 快捷命令
- 多协议节点管理（含 Reality / AnyTLS / CFtunnel）
- 基础自动运维（服务管理、日志清理、定时任务）

这份 README 的目标是让两类人都能快速上手：

- 使用者：快速安装和管理节点
- 开发者：即使第一次接触这个项目，也能在 30 分钟内开始改代码

---

## 1. 功能概览

- 支持 20+ 协议与组合
- 菜单 + 命令行双入口
- 订阅聚合导出（Base64 / 临时 Web）
- Reality 域名池管理（健康检查、权重、区域）
- Cloudflare Tunnel 场景支持（无公网 IP 可用）

---

## 2. 运行环境

### 2.1 服务器环境（运行脚本）

- Ubuntu 20.04+
- Debian 11+
- CentOS 7+
- 架构：`x86_64` / `arm64`
- 必须使用 `root`
- 依赖：`wget` `curl` `tar` `jq`（安装脚本会尽量自动补齐）

### 2.2 开发环境（改代码）

- 任意能运行 `bash` 的开发机（Linux / macOS / WSL 推荐）
- 建议安装：
  - `shellcheck`
  - `shfmt`
- 可选：
  - 一台测试 VPS（用于真实验证 `sb add` / `sb restart`）

---

## 3. 快速安装（用户）

```bash
bash <(curl -s -L https://raw.githubusercontent.com/LuoPoJunZi/sing-box-ev/main/install.sh)
```

备用：

```bash
bash <(curl -s -L https://github.com/LuoPoJunZi/sing-box-ev/raw/main/install.sh)
```

安装后常用命令：

```bash
sb          # 打开主菜单
sb help     # 查看帮助
sb version  # 查看版本
sb status   # 查看运行状态
```

---

## 4. 常用命令（用户）

| 命令 | 说明 |
| --- | --- |
| `sb a <protocol>` | 添加节点，例如 `sb a reality` |
| `sb i <name>` | 查看单节点信息 |
| `sb c <name>` | 更改节点配置 |
| `sb d <name>` | 删除节点 |
| `sb sub` | 生成订阅 |
| `sb all` | 列出所有节点链接 |
| `sb log` | 查看日志 |
| `sb update [core|sh|caddy|cloudflared] [ver]` | 安全更新组件，失败自动回滚 |
| `sb doctor` | 系统诊断（环境/颜色/依赖/服务/端口/配置/网络/客户端兼容） |
| `sb dry-run <command> [args...]` | 预演命令，不执行写入/重启 |
| `sb dry-run uninstall` | 预览完全卸载范围，不执行删除 |
| `sb manifest [summary|list|raw]` | 查看安装清单摘要、明细或原文 |
| `sb backup list` | 查看配置快照 |
| `sb backup create [reason]` | 手动创建快照 |
| `sb rollback [snapshot_id]` | 回滚到快照 |
| `sb domain list` | 查看 Reality 域名池 |
| `sb domain add <domain> [weight] [region]` | 添加域名到域名池 |
| `sb domain del <domain>` | 从域名池移除域名 |
| `sb domain test [region] [domain]` | 做健康检查 |
| `sb domain pick [region]` | 预览自动选择结果 |

### 4.1 节点导出兼容

- VLESS/Reality、VMess、Trojan、Hysteria2、TUIC、Shadowsocks 和 SOCKS 分享内容会统一转义备注、路径和认证信息。
- Reality 链接包含 `sni`、`pbk`、`sid` 和 `fp`；域名 TLS 节点显式包含 SNI。
- Trojan 和 VMess-QUIC 只使用 `pcs` 固定证书，不再导出 `insecure/allowInsecure`。
- Hysteria2 按官方格式使用 `insecure=1 + pinSHA256`；TUIC 通用链接使用 `insecure=1 + pcs`。这两类链接不会允许缺少固定指纹的单独 `insecure`。
- v2rayN 的 sing-box 出站暂不会把 URI 的 `pcs` 映射为 sing-box 公钥指纹，因此 `sb info <配置名>` 会继续输出 `certificate_public_key_sha256` 安全配置片段。
- 如果证书指纹无法计算，脚本会拒绝生成该节点的 URL、二维码和订阅条目，不会退回到不验证证书。
- 脚本更新后，客户端中已经导入的旧节点不会自动刷新；请重新运行 `sb url <配置名>` 或重新生成订阅后导入。

兼容实现参考 [v2rayN allowInsecure 迁移说明](https://github.com/2dust/v2rayN/discussions/9460)、[v2rayN 7.24.6](https://github.com/2dust/v2rayN/releases/tag/7.24.6)、[Xray-core v26.7.28](https://github.com/XTLS/Xray-core/releases/tag/v26.7.28)、[Xray 分享链接规范](https://github.com/XTLS/Xray-core/discussions/716)、[Hysteria2 URI Scheme](https://v2.hysteria.network/docs/developers/URI-Scheme/) 和 [sing-box TLS](https://sing-box.sagernet.org/configuration/shared/tls/)。

### 4.2 安全更新与 sing-box 1.14 兼容

- 官方组件从 GitHub Release 下载，并校验 Release 资源的 SHA-256；校验值缺失或不匹配时不会替换本机文件。
- 核心和 Caddy 更新会先校验候选文件及现有配置，替换后检查服务状态，异常时自动恢复旧版本。
- 脚本更新会保留安装清单、配置快照和 Reality 域名池数据；cloudflared 更新后会检查已有隧道服务。
- cloudflared `2026.8.0` 和 `2026.8.1` 存在官方确认的 HTTP 路径处理问题，更新器会拒绝安装；`sb doctor` 也会提醒已安装用户升级到 `2026.8.2` 或更高版本。
- `sb doctor` 会检查 sing-box 是否达到建议最低稳定版 `1.13.19`，并按文件列出旧 DNS server、FakeIP、DNS 规则、缓存字段和内联 ACME 等兼容风险。
- 普通主配置 `dns.servers[].address` 可由 `sb update core` 安全迁移；特殊 DNS server、节点目录中的旧 DNS 格式或 1.14 冲突规则会在更新前被阻止并要求手动处理。
- 默认更新继续跟随 sing-box 正式稳定版，不自动安装 1.14 beta；1.14 新增但计划在 1.16 移除的弃用字段会提前提示，方便逐步清理。

---

## 5. 仓库结构（开发者必读）

```text
.
├─ install.sh                         # 一键安装入口，负责下载、安装、初始化服务
├─ sing-box.sh                        # 安装后的 CLI 入口，最终调用 src/init.sh
├─ README.md                          # 中文说明文档
├─ README.en.md                       # English documentation
├─ CONTRIBUTING.md                    # 贡献与开发约定
├─ docs
│  └─ VPS_REGRESSION.md               # 真实 VPS 回归测试清单
├─ scripts
│  ├─ check-structure.sh              # 检查模块加载目标是否存在
│  ├─ check-release.sh                # 检查版本号与发布说明
│  ├─ lint.sh                         # 本地 lint 汇总入口
│  ├─ regression-cli.sh               # 可重复执行的 CLI 回归检查
│  ├─ smoke.sh                        # 基础 smoke 检查
│  └─ smoke-reality.sh                # Reality 专项 smoke 检查
├─ .github
│  └─ workflows
│     ├─ lint.yml                     # GitHub Actions: Shell Lint
│     └─ release.yml                  # GitHub Actions: Auto Release
└─ src
   ├─ init.sh                         # 初始化全局变量、路径、运行状态并加载 core
   ├─ core.sh                         # 模块加载顺序 + 对外兼容包装函数
   ├─ utils.sh                        # 安装期/运行期共享工具加载入口
   ├─ help.sh                         # help/about 文档输出
   ├─ caddy.sh                        # Caddy 配置生成与维护
   ├─ import.sh                       # 外部配置导入逻辑
   ├─ lib                             # 跨安装期和运行期复用的公共库
   │  ├─ crypto.sh                    # UUID、Reality keypair 等生成辅助
   │  ├─ download.sh                  # GitHub Release 元数据与 SHA-256 下载校验
   │  ├─ firewall.sh                  # 防火墙端口记录与清理
   │  ├─ fs.sh                        # 文件/目录安全操作与清单记录
   │  ├─ json.sh                      # jq 写入、配置校验辅助
   │  ├─ manifest.sh                  # 安装清单记录与读取
   │  ├─ net.sh                       # IP 获取、端口检测、端口分配
   │  ├─ systemd.sh                   # systemd service 写入与清理
   │  └─ tunnel.sh                    # Cloudflare Tunnel 辅助
   └─ core                            # 业务核心目录，按职责拆分
      ├─ admin
      │  ├─ dispatch.sh               # CLI/menu 统一命令分发
      │  ├─ menu.sh                   # 主菜单展示和输入
      │  ├─ menu_actions.sh           # 菜单选项到命令的映射
      │  ├─ uninstall.sh              # 完全卸载流程
      │  └─ update.sh                 # core/script/caddy/cloudflared 事务更新
      ├─ domain
      │  ├─ cli.sh                    # sb domain 子命令
      │  ├─ health.sh                 # DNS/TCP/TLS 健康检查和缓存
      │  ├─ pick.sh                   # Reality SNI 自动选择
      │  ├─ pool.sh                   # 内置/自定义/禁用域名聚合
      │  └─ store.sh                  # 域名池本地文件初始化
      ├─ env
      │  └─ defaults.sh               # 协议列表、修改项、内置 Reality 域名池
      ├─ node
      │  ├─ add.sh                    # 添加节点主流程
      │  ├─ create.sh                 # 写入 sing-box JSON 配置
      │  ├─ delete.sh                 # 删除节点配置
      │  ├─ change.sh                 # 修改节点主流程
      │  ├─ add/prepare.sh            # 添加节点前的参数准备
      │  └─ change/actions.sh         # 端口/密钥/SNI 等修改动作
      ├─ query
      │  ├─ info.sh                   # 节点信息展示
      │  ├─ parse.sh                  # 配置读取和字段解析
      │  ├─ protocol.sh               # 协议 JSON 片段准备
      │  ├─ tls_pin.sh                # TLS 证书固定指纹提示
      │  └─ url.sh                    # URL/二维码/全部节点输出
      ├─ runtime
      │  ├─ cron.sh                   # 自动维护任务
      │  ├─ doctor.sh                 # 系统诊断
      │  ├─ manifest.sh               # 安装清单展示
      │  ├─ rollback.sh               # 快照回滚
      │  ├─ service.sh                # 启动/停止/重启服务
      │  └─ snapshot.sh               # 快照创建和列表
      ├─ sub/generate.sh              # 订阅生成
      ├─ ui
      │  ├─ output.sh                 # 输出、列表、暂停、页脚
      │  └─ prompt.sh                 # 协议选择、配置选择、通用输入
      ├─ utils
      │  ├─ bbr.sh                    # BBR 开启
      │  ├─ dns.sh                    # DNS 设置
      │  ├─ download.sh               # 版本获取与下载
      │  └─ log.sh                    # 日志查看
      └─ validate/input.sh            # 域名、端口、UUID、路径校验
```

### 5.1 模块职责速查

- `src/core/domain/`：Reality 域名池、权重、健康检查、自动选择
- `src/core/runtime/`：诊断、快照、回滚、服务、Cron
- `src/core/query/`：配置解析、节点展示、URL/二维码输出、客户端 TLS 指纹提示
- `src/core/node/`：节点新增、修改、删除
- `src/core/admin/`：菜单展示、菜单动作映射、CLI 分发、更新、卸载
- `src/core/env/`：常量、协议列表、默认值
- `src/core/ui/`：UI 输出、交互输入、暂停、页脚
- `src/core/validate/`：输入和端口校验
- `src/core/sub/`：订阅生成
- `src/lib/`：安装期与运行期共享工具库
- `src/core/utils/`：下载、BBR、日志、DNS 等运行期工具

说明：

- 旧编号模块已经移除，现在由 `src/core.sh` 直接加载目录化模块。
- 主菜单和命令层已经分离：`menu.sh` 只负责显示和读取选择，`menu_actions.sh` 把选择转换成命令，`dispatch.sh` 统一执行命令。
- 新增能力时优先放到对应模块目录，不建议继续新增大而全的单文件。

---

## 6. 调用链路（理解代码最快方式）

执行 `sb add reality` 时，路径如下：

1. `sing-box.sh` 接收参数
2. `src/init.sh` 初始化环境并加载核心
3. `src/core.sh` 加载模块并提供兼容包装
4. `src/core/admin/dispatch.sh` 路由命令
5. `src/core/node/` 处理写入
6. `src/core/query/` 生成展示和 URL

简单原则：

- 分发逻辑在 `src/core/admin/dispatch.sh`
- 写入逻辑在 `src/core/node/`
- 查询展示在 `src/core/query/`
- 不要把分发、写入、查询混在同一个改动里

---

## 7. 新人接手开发流程（推荐）

### 7.1 第一次克隆后做什么

```bash
git clone https://github.com/LuoPoJunZi/sing-box-ev.git
cd sing-box-ev
```

阅读顺序建议：

1. `README.md`
2. `CONTRIBUTING.md`
3. `src/core/README.md`
4. `src/core/admin/dispatch.sh`
5. 目标模块（例如 `src/core/node/`）

### 7.2 第一个改动怎么做

示例：你要改 `Reality` 新增参数

1. 在 `src/core/admin/dispatch.sh` 确认命令入口
2. 在 `src/core/node/` 修改入参解析和写入逻辑
3. 在 `src/core/query/` 确认 URL/展示同步
4. 若新增默认项，更新 `src/core/env/`
5. 更新帮助文档（`help.sh`）

### 7.3 本地检查

```bash
bash scripts/lint.sh
bash scripts/check-release.sh
bash scripts/smoke.sh
bash scripts/regression-cli.sh
# 可选：真实环境下
bash scripts/smoke-reality.sh
```

`smoke-reality.sh` 会创建并删除 Reality 测试节点，请只在测试机执行。
完整 VPS 回归清单见 [docs/VPS_REGRESSION.md](./docs/VPS_REGRESSION.md)。

如果只想安全检查只读命令，运行：

```bash
bash scripts/regression-cli.sh
```

`regression-cli.sh` 会同时执行 `NO_COLOR=1 sb doctor`、`sb manifest` 和 `sb dry-run uninstall`，用于确认诊断输出、安装清单展示和卸载预演都能在真实环境下正常工作；普通 `sb doctor` 会展示终端颜色样例，并检查协议身份字段、TLS 文件和证书固定状态。回归脚本会按“协议 + 传输方式”各抽查一个代表节点的 `info/url` 输出。

如果在一次性测试 VPS 上允许创建快照，运行：

```bash
ALLOW_WRITES=1 bash scripts/regression-cli.sh
```

---

## 8. Reality 域名池开发说明

`src/core/domain/` 提供了四类能力：

1. 域名池聚合：内置 + 自定义
2. 加权选择：高权重域名更容易被挑中
3. 健康探测：DNS / TCP443 / TLS 探针（按可用工具降级）
4. 最近避让：避免连续重复同一 SNI

存储文件位于：`$is_sh_dir`（默认 `/etc/sing-box/sh`）

- `domain_custom.list`
- `domain_disabled.list`
- `domain_health.cache`
- `domain_recent.list`

如果你要扩展策略（比如按运营商/ASN），优先从 `src/core/domain/` 扩展，不要把策略散落到查询或写入模块。

---

## 9. CI、发布与版本

### 9.1 CI

- `.github/workflows/lint.yml`
- 执行：`shellcheck` + `shfmt` + 结构检查

### 9.2 发布

- `.github/workflows/release.yml`
- 从 `src/init.sh` 的 `is_sh_ver` 提取版本
- 版本号使用 `v年.月.日`：两位年份、不补零的月份和日期，例如 `v26.7.15`
- 同一天只发布一个版本；当天的修改应在发布前合并到同一份 Release Notes
- 从 `RELEASE_NOTES.md` 中提取当前版本的 `### 主要变化`
- 若 tag 不存在则自动打包发布

发布前请确认：

1. `is_sh_ver` 已更新
2. `RELEASE_NOTES.md` 已添加对应版本的 `### 主要变化`
3. `bash scripts/check-release.sh` 通过
4. 本地 lint/smoke 通过
5. README 和 help 文档同步
6. VPS 回归清单已按风险选择执行

如果要在发版前确认本地没有同名 tag，可执行：

```bash
RELEASE_CHECK_STRICT_TAG=1 bash scripts/check-release.sh
```

---

## 10. 常见开发任务改哪里

### 新增命令

- 分发：`src/core/admin/dispatch.sh`
- 帮助：`help.sh`
- 必要时增加模块函数，再在 `core.sh` 增加包装

### 新增协议字段

- 默认值与列表：`src/core/env/`
- 写入：`src/core/node/`
- 展示/URL：`src/core/query/`
- 校验：`src/core/validate/`

### 服务行为修改

- 服务控制：`src/core/runtime/`
- systemd 模板：`src/lib/systemd.sh`
- 下载逻辑：`src/core/utils/download.sh`

---

## 11. 常见问题（开发视角）

### Q1: 为什么改了命令但菜单不生效？

先检查 `src/core/admin/dispatch.sh` 是否接入分发，再检查 `src/core.sh` 是否有包装函数。

### Q2: 为什么 URL 显示不对但配置文件是对的？

配置文件写入在 `src/core/node/`，URL 组装在 `src/core/query/`，两边都要改。

### Q3: 为什么 lint 通过但运行异常？

Shell 项目容易出现运行时依赖问题（`jq`/`openssl`/`timeout` 等），请在真实 Linux 环境做 smoke。

### Q4: 我只想临时禁用某个 Reality 域名？

直接执行：

```bash
sb domain del example.com
```

对内置域名，这会写入禁用清单，不会改动源码。

---

## 12. 安全与运维提醒

- 生产机不要随意执行来源不明脚本
- 官方组件下载必须保留 HTTPS 证书验证和 SHA-256 校验，不要恢复 `--no-check-certificate`
- 改动涉及 `rm -rf`、`systemctl disable`、`crontab -` 时必须二次确认
- 提交 PR 前请说明风险和回滚方式

---

## 13. 贡献与致谢

- 贡献指南见 [CONTRIBUTING.md](./CONTRIBUTING.md)
- 核心项目：`SagerNet/sing-box`
- 本项目基于 233boy 生态做重构与扩展
- 开源协议：`GPL v3`
