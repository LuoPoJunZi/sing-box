<div align="center">
  <h1>sing-box</h1>
  <p>One-command installation and node management for Linux servers</p>
  <p><strong>Easy setup · Clear menus · Reliable updates · Safe rollback</strong></p>

  <p>
    <a href="https://www.gnu.org/software/bash/"><img alt="Language: Bash" src="https://img.shields.io/badge/Language-Bash-4EAA25?style=flat-square&amp;logo=gnubash&amp;logoColor=white"></a>
    <img alt="Platform: Linux" src="https://img.shields.io/badge/Platform-Linux-FCC624?style=flat-square&amp;logo=linux&amp;logoColor=black">
    <a href="https://github.com/LuoPoJunZi/sing-box/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/LuoPoJunZi/sing-box?style=flat-square&amp;label=Version&amp;color=0A7FBC"></a>
    <a href="./LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/github/license/LuoPoJunZi/sing-box?style=flat-square&amp;label=License&amp;color=007EC6"></a>
  </p>

  <p>
    <a href="./README.md"><img alt="简体中文" src="https://img.shields.io/badge/-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-244B5A?style=for-the-badge"></a>
    <a href="./README.en.md"><img alt="English" src="https://img.shields.io/badge/-ENGLISH-244B5A?style=for-the-badge"></a>
  </p>
</div>

---

## 1. Feature Overview

- 20+ protocols and combinations
- Menu-driven and command-driven workflows
- Subscription export (Base64 / temporary web endpoint)
- Reality domain pool management (health checks, weight, region)
- Cloudflare Tunnel support for no-public-IP scenarios

---

## 2. Environment Requirements

### 2.1 Server Runtime

- Ubuntu 20.04+
- Debian 11+
- CentOS 7+
- Architecture: `x86_64` / `arm64`
- Root user required
- Typical dependencies: `wget` `curl` `tar` `jq` (installer will try to install)

### 2.2 Development Environment

- Any environment with `bash` (Linux/macOS/WSL recommended)
- Recommended tools:
  - `shellcheck`
  - `shfmt`
- Optional:
  - A test VPS for integration checks

---

## 3. Quick Install (User)

```bash
bash <(curl -s -L https://raw.githubusercontent.com/LuoPoJunZi/sing-box/main/install.sh)
```

Fallback:

```bash
bash <(curl -s -L https://github.com/LuoPoJunZi/sing-box/raw/main/install.sh)
```

Common startup commands:

```bash
sb
sb help
sb version
sb status
```

---

## 4. Common Commands (User)

| Command | Description |
| --- | --- |
| `sb a <protocol>` | Add a node, e.g. `sb a reality` |
| `sb i <name>` | Show node details |
| `sb c <name>` | Change node settings |
| `sb d <name>` | Delete node |
| `sb sub` | Generate subscription |
| `sb all` | Print all node URLs |
| `sb log` | Tail runtime logs |
| `sb update [core|sh|caddy|cloudflared] [ver]` | Safely update a component with automatic rollback |
| `sb doctor` | Run system diagnostics (environment/colors/dependencies/services/ports/config/network/client compatibility) |
| `sb dry-run <command> [args...]` | Preview command without applying writes/restarts |
| `sb dry-run uninstall` | Preview the complete uninstall scope without deleting anything |
| `sb manifest [summary|list|raw]` | Show install manifest summary, details, or raw records |
| `sb backup list` | List configuration snapshots |
| `sb backup create [reason]` | Create a snapshot manually |
| `sb rollback [snapshot_id]` | Roll back to a snapshot |
| `sb domain list` | List Reality domain pool |
| `sb domain add <domain> [weight] [region]` | Add a domain |
| `sb domain del <domain>` | Remove/disable a domain |
| `sb domain test [region] [domain]` | Run health checks |
| `sb domain pick [region]` | Preview selected domain |

### 4.1 Share-Link Compatibility

- VLESS/Reality, VMess, Trojan, Hysteria2, TUIC, Shadowsocks, and SOCKS exports consistently escape remarks, paths, and credentials.
- Reality links include `sni`, `pbk`, `sid`, and `fp`; domain TLS links include an explicit SNI.
- Trojan and VMess-QUIC use only `pcs` for certificate pinning and no longer export `insecure/allowInsecure`.
- Hysteria2 follows its official `insecure=1 + pinSHA256` format. The common TUIC link uses `insecure=1 + pcs`; neither is allowed without a certificate pin.
- v2rayN currently does not map URI `pcs` to the sing-box public-key pin, so `sb info <config>` continues to print a secure `certificate_public_key_sha256` client snippet.
- If the certificate fingerprint cannot be calculated, the script refuses to generate that node's URL, QR code, or subscription entry instead of falling back to unverified TLS.
- Previously imported client profiles are not updated automatically. Run `sb url <config>` again or regenerate the subscription and re-import it after upgrading the script.

The compatibility implementation follows the [v2rayN allowInsecure migration note](https://github.com/2dust/v2rayN/discussions/9460), [v2rayN 7.24.6](https://github.com/2dust/v2rayN/releases/tag/7.24.6), [Xray-core v26.7.28](https://github.com/XTLS/Xray-core/releases/tag/v26.7.28), the [Xray share-link proposal](https://github.com/XTLS/Xray-core/discussions/716), the [Hysteria2 URI Scheme](https://v2.hysteria.network/docs/developers/URI-Scheme/), and [sing-box TLS](https://sing-box.sagernet.org/configuration/shared/tls/).

### 4.2 Secure Updates and sing-box 1.14 Readiness

- Official components are downloaded from GitHub Releases and checked against each asset's SHA-256 digest. Missing or mismatched digests prevent replacement.
- Core and Caddy candidates are validated against the current configuration before replacement, followed by a service health check and automatic rollback on failure.
- Script updates preserve the install manifest, configuration snapshots, and Reality domain-pool data. cloudflared updates also check existing tunnel services.
- cloudflared `2026.8.0` and `2026.8.1` contain confirmed HTTP path-handling regressions. The updater refuses them, and `sb doctor` tells affected users to install `2026.8.2` or later.
- `sb doctor` checks the recommended minimum stable sing-box version (`1.13.19`) and reports legacy DNS servers, FakeIP, DNS rules, cache fields, inline ACME, and other migration risks per file.
- Plain `dns.servers[].address` entries in the main config can still be migrated transactionally. Special DNS servers, legacy DNS entries in node files, and conflicting 1.14 DNS rules block the update until they are handled manually.
- Default updates continue to follow stable sing-box releases rather than 1.14 betas. Fields introduced as deprecated in 1.14 and planned for removal in 1.16 are reported early for gradual cleanup.

---

## 5. Repository Structure (Developer)

```text
.
├─ install.sh                         # one-click installer and bootstrap entry
├─ sing-box.sh                        # installed CLI entry; loads src/init.sh
├─ README.md                          # Chinese documentation
├─ README.en.md                       # English documentation
├─ CONTRIBUTING.md                    # contribution and development rules
├─ docs
│  └─ VPS_REGRESSION.md               # real VPS regression checklist
├─ scripts
│  ├─ check-structure.sh              # validates sourced module targets
│  ├─ check-release.sh                # validates version and release notes
│  ├─ lint.sh                         # local lint wrapper
│  ├─ regression-cli.sh               # repeatable CLI regression checks
│  ├─ smoke.sh                        # basic smoke checks
│  └─ smoke-reality.sh                # Reality-focused smoke checks
├─ .github
│  └─ workflows
│     ├─ lint.yml                     # GitHub Actions: Shell Lint
│     └─ release.yml                  # GitHub Actions: Auto Release
└─ src
   ├─ init.sh                         # initializes paths, runtime state, and core loading
   ├─ core.sh                         # module loading order and compatibility wrappers
   ├─ utils.sh                        # shared helper loader for install/runtime flows
   ├─ help.sh                         # help/about output
   ├─ caddy.sh                        # Caddy configuration generation and maintenance
   ├─ import.sh                       # external configuration import
   ├─ lib                             # shared libraries used by installer and runtime
   │  ├─ crypto.sh                    # UUID and Reality keypair helpers
   │  ├─ download.sh                  # GitHub Release metadata and SHA-256 verification
   │  ├─ firewall.sh                  # firewall port tracking and cleanup
   │  ├─ fs.sh                        # safe file/dir operations and manifest helpers
   │  ├─ json.sh                      # jq writes and config validation helpers
   │  ├─ manifest.sh                  # install manifest read/write helpers
   │  ├─ net.sh                       # IP, port checks, and port allocation
   │  ├─ systemd.sh                   # systemd service writes and cleanup
   │  └─ tunnel.sh                    # Cloudflare Tunnel helpers
   └─ core                            # business core split by responsibility
      ├─ admin
      │  ├─ dispatch.sh               # unified CLI/menu command dispatch
      │  ├─ menu.sh                   # main menu rendering and input
      │  ├─ menu_actions.sh           # menu choice to command mapping
      │  ├─ uninstall.sh              # complete uninstall flow
      │  └─ update.sh                 # transactional core/script/caddy/cloudflared updates
      ├─ domain
      │  ├─ cli.sh                    # sb domain subcommands
      │  ├─ health.sh                 # DNS/TCP/TLS health checks and cache
      │  ├─ pick.sh                   # Reality SNI auto-pick
      │  ├─ pool.sh                   # built-in/custom/disabled pool merge
      │  └─ store.sh                  # local domain-pool file initialization
      ├─ env
      │  └─ defaults.sh               # protocols, change actions, built-in Reality domains
      ├─ node
      │  ├─ add.sh                    # add-node main flow
      │  ├─ create.sh                 # sing-box JSON config writing
      │  ├─ delete.sh                 # node config deletion
      │  ├─ change.sh                 # change-node main flow
      │  ├─ add/prepare.sh            # add-node parameter preparation
      │  └─ change/actions.sh         # port/key/SNI and other change actions
      ├─ query
      │  ├─ info.sh                   # node information display
      │  ├─ parse.sh                  # config reading and field parsing
      │  ├─ protocol.sh               # protocol JSON fragment preparation
      │  ├─ tls_pin.sh                # TLS certificate pinning hints
      │  └─ url.sh                    # URL/QR/all-node output
      ├─ runtime
      │  ├─ cron.sh                   # automatic maintenance tasks
      │  ├─ doctor.sh                 # system diagnostics
      │  ├─ manifest.sh               # install manifest display
      │  ├─ rollback.sh               # snapshot rollback
      │  ├─ service.sh                # service start/stop/restart
      │  └─ snapshot.sh               # snapshot create/list helpers
      ├─ sub/generate.sh              # subscription generation
      ├─ ui
      │  ├─ output.sh                 # output, lists, pause, footer
      │  └─ prompt.sh                 # protocol/config/common prompts
      ├─ utils
      │  ├─ bbr.sh                    # BBR enablement
      │  ├─ dns.sh                    # DNS settings
      │  ├─ download.sh               # version lookup and downloads
      │  └─ log.sh                    # log viewing
      └─ validate/input.sh            # domain, port, UUID, and path validation
```

### 5.1 Module Responsibility Quick Map

- `src/core/domain/`: Reality domain pool, weights, health checks, auto-pick
- `src/core/runtime/`: diagnostics, snapshots, rollback, service, cron
- `src/core/query/`: config parsing, node display, URL/QR output, client TLS pinning hints
- `src/core/node/`: node add/change/delete flows
- `src/core/admin/`: menu rendering, menu action mapping, CLI dispatch, update, uninstall
- `src/core/env/`: constants, protocol lists, defaults
- `src/core/ui/`: output, interactive prompts, pause, footer
- `src/core/validate/`: input and port validation
- `src/core/sub/`: subscription generation
- `src/lib/`: shared install-time and runtime helper libraries
- `src/core/utils/`: runtime utility helpers for download, BBR, logs, and DNS

Notes:

- Legacy numbered modules have been removed. `src/core.sh` now loads directory-based modules directly.
- The menu and command layers are separated: `menu.sh` only renders and reads choices, `menu_actions.sh` maps choices to commands, and `dispatch.sh` executes commands.
- Add new behavior under the closest responsibility-based module instead of creating another large all-in-one file.

---

## 6. Execution Flow (Fastest Way to Understand)

For `sb add reality`, the call chain is:

1. `sing-box.sh` receives CLI args
2. `src/init.sh` initializes runtime variables and loads core
3. `src/core.sh` loads modules and compatibility wrappers
4. `src/core/admin/dispatch.sh` dispatches the command
5. `src/core/node/` handles write path
6. `src/core/query/` handles render/URL path

Rule of thumb:

- Dispatch in `src/core/admin/dispatch.sh`
- Write logic in `src/core/node/`
- Read/display logic in `src/core/query/`
- Keep concerns separated in PRs

---

## 7. New Contributor Workflow (Recommended)

### 7.1 First Read Order

1. `README.md`
2. `CONTRIBUTING.md`
3. `src/core/README.md`
4. `src/core/admin/dispatch.sh`
5. Target module (`src/core/node/`, `src/core/query/`, etc.)

### 7.2 First Change Pattern

Example: changing Reality add behavior

1. Check command routing in `src/core/admin/dispatch.sh`
2. Edit input/write logic under `src/core/node/`
3. Sync render and URL under `src/core/query/`
4. Update defaults under `src/core/env/` if needed
5. Update docs in `src/help.sh`

### 7.3 Local Checks

```bash
bash scripts/lint.sh
bash scripts/check-release.sh
bash scripts/smoke.sh
bash scripts/regression-cli.sh
# Optional on test host:
bash scripts/smoke-reality.sh
```

`smoke-reality.sh` creates and removes Reality test nodes; run it on test environments only.
Full VPS regression steps are documented in [docs/VPS_REGRESSION.md](./docs/VPS_REGRESSION.md).

For read-only CLI checks:

```bash
bash scripts/regression-cli.sh
```

`regression-cli.sh` also runs `NO_COLOR=1 sb doctor`, `sb manifest`, and `sb dry-run uninstall` to ensure diagnostics, manifest display, and uninstall preview work in real environments. Regular `sb doctor` prints a terminal color sample and checks protocol credentials, TLS files, and certificate-pin readiness. The regression script samples one `info/url` export for each protocol and transport combination.

On a disposable VPS where snapshot creation is allowed:

```bash
ALLOW_WRITES=1 bash scripts/regression-cli.sh
```

---

## 8. Reality Domain Pool Development Notes

`src/core/domain/` provides:

1. Pool aggregation: built-in + custom domains
2. Weighted selection: high weight has higher chance
3. Health probing: DNS / TCP443 / TLS handshake (degrades by available tools)
4. Recent avoidance: reduce repeated SNI reuse

Data files are stored under `$is_sh_dir` (usually `/etc/sing-box/sh`):

- `domain_custom.list`
- `domain_disabled.list`
- `domain_health.cache`
- `domain_recent.list`

If you extend selection strategy, prioritize adding it under `src/core/domain/` instead of scattering logic in query/write modules.

---

## 9. CI, Release, and Versioning

### 9.1 CI

- Workflow: `.github/workflows/lint.yml`
- Checks: `shellcheck` + `shfmt` + structure checks

### 9.2 Release

- Workflow: `.github/workflows/release.yml`
- Version source: `is_sh_ver` in `src/init.sh`
- Version format: `vYY.M.D`, using a two-digit year and month/day without leading zeros, for example `v26.7.15`
- Publish at most one version per day; combine same-day changes into the same release notes before publishing
- Release body source: the matching version's `### 主要变化` section in `RELEASE_NOTES.md`
- Auto-release runs when version tag is new

Before release, verify:

1. `is_sh_ver` is updated
2. `RELEASE_NOTES.md` contains `### 主要变化` for the target version
3. `bash scripts/check-release.sh` passes
4. local lint/smoke checks pass
5. README/help docs reflect behavior
6. VPS regression checklist has been run as appropriate for the risk level

To verify that a new release tag does not already exist locally before publishing:

```bash
RELEASE_CHECK_STRICT_TAG=1 bash scripts/check-release.sh
```

---

## 10. Where to Edit for Common Dev Tasks

### Add a new command

- Routing: `src/core/admin/dispatch.sh`
- Help docs: `src/help.sh`
- Optional wrapper: `src/core.sh`

### Add/change protocol fields

- Defaults: `src/core/env/`
- Write path: `src/core/node/`
- Display/URL path: `src/core/query/`
- Validation: `src/core/validate/`

### Change runtime behavior

- Service/cron operations: `src/core/runtime/`
- Service templates: `src/lib/systemd.sh`
- Download logic: `src/core/utils/download.sh`

---

## 11. FAQ (Developer View)

### Q1: I changed a command but it does not show up.

Check command dispatch in `src/core/admin/dispatch.sh` and wrapper exposure in `src/core.sh`.

### Q2: Config is correct but URL output is wrong.

Write logic is under `src/core/node/`; URL rendering is under `src/core/query/`. Both may require updates.

### Q3: Lint passes but runtime fails.

This project depends on runtime tools (`jq`, `openssl`, `timeout`, etc.). Validate on a real Linux host.

### Q4: I want to disable one Reality domain quickly.

```bash
sb domain del example.com
```

For built-in domains, this writes to disable list without source edits.

---

## 12. Security and Ops Reminders

- Do not run unknown scripts on production hosts
- Keep HTTPS certificate validation and SHA-256 verification enabled for official component downloads; do not restore `--no-check-certificate`
- Double-check changes touching `rm -rf`, `systemctl disable`, or `crontab -`
- In PRs, include risk and rollback notes for operational changes

---

## 13. Contribution and Acknowledgements

- Contribution guide: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Upstream core: `SagerNet/sing-box`
- This project is a refactor/extension built on the 233boy ecosystem
- License: GPL v3
