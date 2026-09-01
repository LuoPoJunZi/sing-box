# Contributing

Thanks for helping improve this sing-box management script.

## Development Principles

- Keep CLI behavior stable by default.
- Prefer small, isolated changes.
- Avoid mixing refactor and feature changes in one PR.
- Never remove user-facing commands without migration notes.

## Script Style

- Target shell: `bash`.
- Every `.sh` file must declare its Bash shebang, including sourced modules.
- Prefer quoted variables (`"$var"`) unless intentional word splitting is required.
- Forward arguments with `"$@"` or `"${@:N}"`, and iterate arrays with `"${array[@]}"`.
- Prefer `command -v` for executable checks and `printf` for formatted output.
- Use function-local variables for temporary state; shared runtime globals should be explicit.
- Prefer explicit function boundaries and single responsibility per file/module.
- Keep destructive operations (`rm -rf`, service stop/disable) guarded by clear conditions.

## Core Module Layout

- `src/core.sh`: module loading order and compatibility wrappers.
- `src/core/admin/`: menu rendering, menu action mapping, CLI dispatch, update, uninstall.
- `src/core/domain/`: Reality domain pool storage, health checks, weighted pick logic, and CLI commands.
- `src/core/env/`: shared protocol lists, change-action lists, defaults, and built-in Reality domains.
- `src/core/node/`: create/add/change/delete write flows and protocol parameter preparation.
- `src/core/query/`: config parsing, info display, URL/QR rendering, and all-node output.
- `src/core/runtime/`: service control, cron, doctor diagnostics, snapshots, and rollback.
- `src/core/sub/`: subscription generation.
- `src/core/ui/`: output helpers and interactive prompt helpers.
- `src/core/validate/`: input, domain, port, UUID, and path validation.
- `src/core/utils/`: runtime utility helpers for download, BBR, logs, and DNS.
- `src/lib/`: shared helpers used by both install-time and runtime flows.

Admin layering rule:

- `menu.sh` renders the menu and reads the user choice.
- `menu_actions.sh` maps menu choices to command arguments.
- `dispatch.sh` is the unified execution path for CLI and menu commands.

## Quality Checks

CI now runs:

- `scripts/check-shell.sh` (warning-level ShellCheck; sourced modules only exclude cross-file global/source analysis rules)
- `scripts/test-install-cli.sh`
- `scripts/test-dispatch.sh`
- `scripts/test-runtime-safety.sh`
- `shfmt -d -i 4 -ci -sr`
- `scripts/check-structure.sh`
- `scripts/check-release.sh`

Please run equivalent checks locally before opening a PR.
When preparing a public release, run `RELEASE_CHECK_STRICT_TAG=1 bash scripts/check-release.sh` if you want the check to fail when the tag already exists locally.

Local helper:

- `bash scripts/check-shell.sh`
- `bash scripts/lint.sh`
- `bash scripts/smoke.sh`

## Commit/PR Guidance

- Use clear commit messages with scope (example: `refactor(core): split query module`).
- Include test notes in PR description (what commands were verified).
- For behavior changes, include before/after examples from CLI output.
- For releases, update `src/init.sh` and add the matching `### 主要变化` section in `RELEASE_NOTES.md`.
