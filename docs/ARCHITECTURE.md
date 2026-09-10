# 架构与开发约定

## 一次命令如何执行

`sing-box.sh → init.sh → core.sh → admin/dispatch.sh → 业务模块`。
CLI 名称、菜单入口、安装路径和分享链接格式保持兼容。

| 模块 | 负责 | 不应负责 |
| --- | --- | --- |
| `env/` | 默认值、只读状态探测 | 补证书、修复服务 |
| `query/` | 读取配置、解释协议、显示和导出 | 生成新密钥、安装或重启服务 |
| `node/protocol.sh` | 写入前的协议默认值和参数准备 | 输出 JSON 源码片段 |
| `node/build.sh` | 将准备好的上下文序列化为 JSON | 网络访问、写文件、服务控制 |
| `node/create.sh` | 编排生成、预演、快照、证书准备和写入 | 分享链接编码 |
| `runtime/` | 服务、证书初始化、诊断和快照 | 菜单选择映射 |
| `admin/` | 命令分发、安装维护、更新和卸载 | 节点 JSON 序列化 |

`core.sh` 中的 `get/create/manage` 等是旧调用接口的适配层，不是新增业务的默认归属。
现有 Bash 模块仍使用共享上下文；不要对整个运行时直接开启 `set -u`。
新增函数应使用前缀、局部临时变量、引用参数，并在失败时返回非零状态。
本轮没有引入框架，也没有更换运行语言。

## 初始化和证书

- 加载脚本不再自动生成证书，也不再修复或重启 Caddy。
- `sb help` 跳过服务状态探测；其他命令的状态探测只读。
- 创建需要自签 TLS 的节点时，才调用 `runtime_ensure_tls`。预演和只生成 JSON 的路径不落盘。
- 新证书通过权限受限的临时目录和互斥目录准备；生成失败不发布不完整内容。
- 已有完整证书对保持原样。如果只剩证书或私钥，不自动覆盖，以免改变已导入客户端的指纹；应从备份恢复匹配的一对文件。
- Caddy 的旧 service 参数修复只在明确启动/重启 Caddy 时进行。

## 配置读取与生成

`query/read.sh` 每次用一个 jq 进程读取节点字段，保留空格、引号、反斜杠、换行及字符串内的 `//`。
它接受标准 JSON；不再用删除行内 `//` 的方式“修复”文件。带注释的手工 JSONC 文件应先转换为标准 JSON。
读取失败会清理上一节点的字段并停止导出；记录分隔符控制字符会被明确拒绝，不会错位读取。

`node_build_config` 使用 `jq --arg` 传递数据，而非将数据拼进 jq 程序。
真实核心测试调用生产的 `write_create → node_prepare_protocol → node_build_config`，
覆盖协议列表中的全部 22 项及 Direct，共 23 种配置。
`AnyTLS` 名称继续保留原有的 VLESS Reality 映射，本轮不改变协议产品语义。

## 诊断与性能

`runtime/doctor.sh` 是稳定加载入口，子目录分为输出、系统检查、版本/配置兼容、客户端检查和编排。
客户端与 Reality 检查分别对每个文件执行一次 jq，而不是逐字段启动进程。
不跨命令缓存配置，避免修改后仍显示旧密码、端口或指纹。

可复现基准（仅构造临时文件，不修改本机已安装服务）：

```bash
BENCH_NODES=20 bash scripts/benchmark-doctor.sh 434a6e5
BENCH_NODES=20 bash scripts/benchmark-doctor.sh
```

2026-09-10，Windows Git Bash + jq 1.8.2，同机一次采样：

| 20 个 Reality 节点的客户端与 Reality 扫描 | 原提交 | 重构后 |
| --- | --- | --- |
| jq 调用次数 | 200 | 40 |
| 耗时 | 22.444 秒 | 4.170 秒 |

调用次数减少 80%；该次采样耗时减少约 81%。这不是网络吞吐、代理延迟或 Linux VPS 性能承诺。
原提交还存在 `jq -e empty` 把有效 JSON 判成失败的问题，基准保留原代码行为；
新版同时恢复了原先被跳过的有效节点检查，不能把两者视为完全相同的诊断结果。

## 测试和发布

- `tests/unit/`：解析、分发、兼容规则、初始化边界等。
- `tests/integration/`：生产配置生成、分享输出、证书初始化、更新回滚等。
- `tests/fixtures/`：确定性测试输入，不复制生产生成算法。
- `tests/e2e/`：真实 VPS 脚本。Reality smoke 会创建/删除节点，只能在测试机执行。
- `scripts/test.sh`：离线测试；`scripts/lint.sh`：统一格式、静态检查和离线测试。
- `tests/integration/test-sing-box-release.sh`：独立运行的真实核心测试，默认联网下载并校验 SHA-256；也可用 `SING_BOX_CORE_BIN` 指定已验证的二进制。

Auto Release 先调用同一提交的可复用 Shell Lint workflow，全部检查成功后才允许发布。
PR 和手动检查只有只读权限；写权限只授予主分支发布任务。
发布包使用明确的文件/目录清单，不打包本地记忆和临时工具。
实现依据：[GitHub 可复用工作流文档](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)。

本地检查不能替代 Linux systemd、实际端口监听、真实安装/卸载和外部客户端导入验证。
发布前仍应执行 VPS 回归清单；提交代码不等于发布新版本。
