# Release Notes

## v26.9.1

### 主要变化

- 项目仓库由 `LuoPoJunZi/sing-box-ev` 更名为更简洁的 `LuoPoJunZi/sing-box`，安装、更新和问题反馈地址已同步切换。
- README、中英文文档、终端菜单和节点总览统一使用 `sing-box` 名称，命令入口 `sb` 与已有配置保持不变。

## v26.8.23

### 主要变化

- 更新器会拒绝安装 cloudflared `2026.8.0` 和 `2026.8.1`，避免这两个官方已确认问题版本引发源站路径异常；候选文件版本与目标版本不一致时也不会替换。
- `sb doctor` 增加 sing-box 核心版本检查，低于 `1.13.19` 时提示升级到包含不可信输入内存分配修复的稳定版本。
- 扩大 sing-box 配置兼容扫描，按文件列出旧 DNS server、FakeIP、DNS 规则、缓存字段和内联 ACME 等待迁移项目。
- 升级 sing-box 1.14 前会提前阻止无法安全自动迁移的配置；普通主配置 DNS address 仍可在候选核心验证通过后自动转换。

## v26.8.11

### 主要变化

- 安装器和运行期下载统一启用 HTTPS 证书验证，并按 GitHub Release 提供的 SHA-256 摘要校验 sing-box、脚本、Caddy 与 cloudflared；校验失败时拒绝安装。
- 新安装缺少 jq 时改用经过固定哈希校验的 jq 1.8.2，脚本安装包改为正式 Release 的 `code.tar.gz`，不再直接获取变化中的 `main` 分支压缩包。
- `sb update` 增加候选版本检查、服务健康检查和失败自动回滚，并支持更新 cloudflared；核心升级会先用新核心校验现有配置。
- 为 sing-box 1.14 的 DNS 变更增加兼容预检：发现旧版 `dns.servers[].address` 时先生成 `type/server` 配置，只有新核心校验通过才写入。
- `sb doctor` 增加 SHA-256 工具、jq 版本和旧 DNS 格式诊断；GitHub Actions 升级并固定到明确提交，Release 改用 GitHub CLI 原生发布。

## v26.7.31

### 主要变化

- 按 Xray-core v26.2.6 与 v2rayN 关于移除 `allowInsecure` 的说明，更新自签证书节点的长期兼容方案。
- Trojan 和 VMess-QUIC 导出彻底移除 `insecure/allowInsecure`，只使用 `pcs` 映射到 Xray 的 `pinnedPeerCertSha256`。
- Hysteria2 保留官方要求的 `insecure=1 + pinSHA256` 组合；TUIC 精简为 `insecure=1 + pcs`，并继续输出 sing-box 的 `certificate_public_key_sha256` 安全配置片段。
- 证书指纹无法计算时将拒绝生成节点 URL、二维码或订阅条目，避免退回到未验证证书的连接方式。
- `sb doctor`、分享链接静态检查和导出回归测试同步验证新规则，并提醒已导入的旧节点需要重新导入。

## v26.7.17

### 主要变化

- 按 v2rayN 7.23.4、Xray 分享链接规范、Hysteria2 URI 规范和 sing-box TLS 配置更新节点导出兼容性。
- Hysteria2 分享链接直接携带 `pinSHA256`；无域名 Trojan、TUIC 和 VMess-QUIC 携带 v2rayN/Xray 可识别的 `pcs` 证书指纹，同时保留旧客户端导入兼容。
- VLESS、VMess、Trojan、Reality、CFtunnel 等链接统一补齐 SNI、路径和参数转义，Shadowsocks/SOCKS 认证信息改用 URL-safe Base64，中文备注和特殊字符可以安全导入。
- `sb doctor` 会检查所有节点 JSON、协议身份字段、TLS 证书路径和固定指纹生成状态，并提醒旧客户端重新导入更新后的链接。
- 本地与 GitHub Actions 新增分享链接结构检查，VPS 回归会按“协议 + 传输方式”抽查代表节点。

## v26.7.15

### 主要变化

- 版本号改为 `v年.月.日` 格式，后续发布可直接看出版本日期；本次版本为 `v26.7.15`。
- 新建 VLESS-REALITY 节点会生成明确的 8 位十六进制 Short ID，并在分享链接中携带 `sid`，提升 v2rayN、Xray 等客户端的导入兼容性。
- `sb doctor` 新增 VLESS-REALITY 专项诊断，可检查 UUID、SNI、Reality 密钥、Short ID 和 TCP 监听状态。
- 诊断输出会明确区分 VLESS 的 TCP 与 Hysteria2 的 UDP，并提醒检查云厂商安全组中的 TCP 入站规则。
- Reality 回归测试新增配置 Short ID 与分享链接 `sid` 校验，降低发布后节点链接不可用的风险。

## v1.5.3

### 主要变化

- 优化 Hysteria2、TUIC、VMess-QUIC 的节点输出，把“兼容导入链接”和“推荐安全配置”分区展示，减少用户误把旧兼容参数当长期方案使用。
- `sb info` 和 `sb url` 的证书固定指纹提示增加操作步骤，提示先确认旧链接可导入，再关闭跳过证书验证并填入指纹。
- `sb doctor` 的客户端兼容扫描会列出受影响配置名，并按协议给出 `pinSHA256`、`certificate_public_key_sha256`、`pinnedPeerCertSha256` 的处理建议。
- VPS 回归脚本会优先抽查 Trojan、Hysteria2、TUIC、VMess-QUIC 等兼容相关配置，帮助在真实环境中验证输出可读性。

## v1.5.2

### 主要变化

- 针对 v2rayN / Xray 后续禁用 `allowInsecure` 的变化，新增 Hysteria2、TUIC、VMess-QUIC 的证书固定指纹提示。
- `sb info` 和 `sb url` 会在相关节点下显示推荐客户端配置片段，方便把 `pinSHA256`、`certificate_public_key_sha256` 或 `pinnedPeerCertSha256` 填入客户端。
- `sb doctor` 新增客户端兼容扫描，可提示现有 Hysteria2、TUIC、VMess-QUIC 节点是否建议迁移到证书固定指纹。
- Trojan 按项目策略保留“无域名 / 自签证书”兼容路线，输出中会明确提示该协议仍依赖兼容导入参数。

## v1.5.1

### 主要变化

- 新增 `sb manifest [summary|list|raw]`，可查看安装清单摘要、托管项明细或原始记录。
- 进阶菜单新增“查看安装清单”，方便从 TUI 直接检查脚本托管的文件、目录、服务、计划任务和防火墙端口。
- `sb dry-run uninstall` 在发现安装清单时会提示使用 `sb manifest list` 查看卸载相关明细。
- VPS 回归脚本增加安装清单展示检查，帮助验证真实环境中的 manifest 覆盖情况。

## v1.5.0

### 主要变化

- 增强 `sb doctor` 一键诊断，覆盖系统环境、依赖工具、服务状态、监听端口、配置校验、网络、磁盘、快照和安装清单。
- 新增终端颜色诊断，显示基础 ANSI 色彩样例，并说明 `NO_COLOR`、`TERM=dumb`、非 TTY 等纯文本模式原因。
- `sb dry-run uninstall` 现在会直接展示完整卸载预览，不确认、不删除，方便提前检查会清理哪些目录、服务、端口和托管项。
- VPS 回归脚本新增 `NO_COLOR=1 sb doctor` 和卸载预演检查，发布前更容易验证真实 Linux 环境下的可读性与安全性。

## v1.4.3

### 主要变化

- 主菜单状态显示增加 `[OK]` / `[STOP]` 标识，运行状态更容易扫读。
- 删除配置、完全卸载等危险操作增加红色强调，成功/警告输出统一使用 `[OK]` / `[WARN]` 前缀。
- 新增 `scripts/check-release.sh`，发布前自动检查版本号、Release Notes 和重复 tag，降低发版遗漏风险。

## v1.4.2

### 主要变化

- 将终端 UI 配色从亮色 ANSI 码 `90-97` 调整为兼容性更好的基础 ANSI 码 `30-37`。
- 修复部分 Linux 终端不识别亮色码，导致菜单和输出看起来几乎没有颜色的问题。
- 安装器和运行时脚本保持同一套基础色定义，确保安装过程与 `sb` 主菜单显示一致。

## v1.4.1

### 主要变化

- GitHub Release 说明现在只展示当前版本的“主要变化”，不再显示发布流程、验证建议等维护内容。
- Auto Release 会从 `RELEASE_NOTES.md` 当前版本下的第一段三级标题内容生成 Release 正文，方便保持页面简洁。
- README、英文 README 和贡献说明已同步新的发布说明规则。

## v1.4.0

### 主要变化

- 终端 UI 改为统一的“清爽科技风”配色：青蓝用于品牌标题和链接，绿色用于成功与可选项，黄色用于提醒，红色用于错误或危险提示，灰色用于分隔线和弱提示。
- 新增语义化 UI 颜色函数：`ui_brand`、`ui_success`、`ui_warn`、`ui_error`、`ui_muted`、`ui_link`、`ui_title`、`ui_key`，后续输出样式可以集中维护。
- 保留 `_red`、`_green`、`_yellow`、`_cyan` 等旧函数，避免影响已有脚本调用。
- 主菜单、协议选择页、进阶菜单、节点信息、URL/二维码输出、订阅生成输出已切换到统一主题函数。
- 节点链接统一使用下划线高亮，Reality、CFtunnel 等特殊节点信息不再依赖裸 ANSI 背景色数字。
- 安装阶段和运行阶段使用一致的颜色定义，安装器与 `sb` 主程序观感保持一致。
- 支持 `NO_COLOR`、`TERM=dumb`、非 TTY 环境自动关闭颜色，方便日志复制、CI 输出和脚本管道使用。
