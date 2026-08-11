# VPS Regression Checklist

> Purpose: verify a released build on a real Linux VPS before treating it as stable.
> Use a disposable test VPS whenever possible. Do not run destructive uninstall checks
> on a production host unless you have a separate backup and a rollback plan.

## 1. Test Host Requirements

- OS: Ubuntu 20.04+, Debian 11+, or CentOS 7+
- User: `root`
- Network: public IPv4 or IPv6 reachable from your client
- Tools: `curl`, `wget`, `jq`, `systemctl`
- Optional: a domain pointed to the VPS for TLS/Caddy scenarios

Record before testing:

```bash
uname -a
cat /etc/os-release
date -u
```

## 2. Fresh Install Flow

```bash
bash <(curl -fsSL sb.evzzz.com)
sb version
sb status
sb help
```

Expected:

- `sb` command exists.
- `sb version` shows the expected script version.
- `sb status` does not crash.
- `sb help` prints command help.

## 3. Read-Only Smoke Checks

```bash
sb doctor
NO_COLOR=1 sb doctor
sb backup list
sb manifest
sb manifest list
sb domain list
sb domain pick
sb all
sb dry-run uninstall
```

Expected:

- Commands return cleanly.
- `doctor` gives actionable output for system, terminal colors, dependencies, services, ports, config, network, disk, snapshots, install manifest, and client compatibility.
- `doctor` lists concrete config names for Trojan/Hysteria2/TUIC/VMess-QUIC when those compatibility-sensitive nodes exist.
- `NO_COLOR=1 sb doctor` remains readable for log copying and CI-style output.
- `sb manifest` shows a readable summary and `sb manifest list` shows managed artifact details.
- `sb dry-run uninstall` prints the uninstall plan without asking for confirmation or deleting anything.
- Empty backup/node states are handled without stack traces or shell errors.

## 4. Node Lifecycle Checks

Reality quick path:

```bash
sb add reality auto auto --auto-sni
sb all
sb info
sb url
sb change
sb del
```

Optional protocol paths:

```bash
sb add tuic auto auto
sb add hysteria2 auto auto
sb add socks auto test-user test-pass
```

Expected:

- Config files are created under `/etc/sing-box/conf`.
- URLs are copy-friendly.
- Hysteria2/TUIC/VMess-QUIC node details separate compatibility URLs from recommended certificate-pinning guidance when applicable.
- Trojan keeps the no-domain/self-signed compatibility notice when applicable.
- `sing-box check` succeeds after create/change/delete.
- Service can restart after each write.

## 5. Snapshot And Rollback Checks

```bash
sb backup create regression-before-change
sb backup list
sb rollback
```

Expected:

- Manual snapshot appears in the list.
- Rollback can select or accept a snapshot id.
- Config and service state are restored after rollback.

## 6. Domain Pool Checks

```bash
sb domain list
sb domain add www.cloudflare.com 8 global
sb domain pick global
sb domain test global www.cloudflare.com
sb domain del www.cloudflare.com
```

Expected:

- Custom domain add/delete does not corrupt built-in pool.
- `pick` still returns a usable fallback if health checks fail.

## 7. Dry-Run Safety Checks

Pick an existing config name from `sb all` or `/etc/sing-box/conf`:

```bash
sb dry-run change <config-name> port auto
sb dry-run change <config-name> key auto
sb dry-run change <config-name> sni auto
sb dry-run uninstall
```

Expected:

- Output clearly says `DRY-RUN`.
- Config files and services are not changed.
- Uninstall preview lists planned directories, commands, services, tunnel artifacts, firewall ports, and install manifest status without prompting.
- If a manifest exists, uninstall preview points users to `sb manifest list` for details.

## 8. Update Checks

Before uninstalling, verify the update path on a disposable host that is one release behind when possible:

```bash
sb update core
sb update sh
sb update caddy          # only when Caddy is installed
sb update cloudflared    # only when cloudflared is installed
systemctl is-active sing-box
sb doctor
```

Expected:

- Downloads report SHA-256 verification before replacement.
- The candidate core validates the current configuration before the running binary changes.
- The service remains active after an update; a failed health check restores the previous binary and configuration.
- Legacy `dns.servers[].address` entries are either reported by `doctor` or migrated only after candidate-core validation.
- Script updates preserve the install manifest, snapshots, and Reality domain-pool data.

## 9. Complete Uninstall Checks

Only run on disposable test hosts:

```bash
sb uninstall
```

After confirmation, verify:

```bash
command -v sb || true
systemctl status sing-box --no-pager || true
systemctl status caddy --no-pager || true
ls -la /etc/sing-box /var/log/sing-box 2>/dev/null || true
```

Expected:

- Script-created commands, services, configs, logs, cron entries, Caddy/CFtunnel artifacts, and tracked firewall rules are removed.
- Local-only files outside the installation path are not touched.

## 10. Result Template

```text
Version:
Commit:
OS:
Architecture:
Install:
Read-only smoke:
Node lifecycle:
Snapshot/rollback:
Domain pool:
Dry-run:
Uninstall:
Issues found:
Release decision:
```
