# Core Modules

This folder contains the refactored core modules for the sing-box management script.

## Module Map

- `env/`
  - Protocol lists, change-action lists, default values, and built-in Reality domain pool.
- `admin/`
  - Menu rendering, menu action mapping, CLI dispatch, update, and uninstall.
- `domain/`
  - Reality domain pool storage, health checks, weighted selection, recent-use avoidance, and `sb domain` CLI.
- `node/`
  - Write/mutate flows: create, add, change, delete, plus protocol parameter preparation.
- `query/`
  - Read/query flows: parse configs, show info, render URLs/QR, and list all nodes.
- `runtime/`
  - Runtime/service operations: service control, cron, doctor, snapshot, rollback.
- `sub/`
  - Subscription generation flow.
- `ui/`
  - UI output, list rendering, pause, footer, and interactive prompt helpers.
- `validate/`
  - Input, domain, port, UUID, and path validation helpers.
- `utils/`
  - Runtime utilities such as download, BBR, log, and DNS helpers.

## Admin Layering

- `admin/menu.sh`: renders the main menu and reads the selected number.
- `admin/menu_actions.sh`: maps menu selections to command arguments.
- `admin/dispatch.sh`: executes both CLI commands and menu commands through one dispatch path.
- Keep menu presentation separate from business operations. Menu code should not call node/runtime/query functions directly.

## Compatibility Rule

- Public function names used by CLI remain in `src/core.sh` as thin wrappers.
- `src/core.sh` loads the directory-based modules directly.
- Modules expose prefixed internal functions (`ui_*`, `validate_*`, `query_*`, `write_*`, `admin_*`).
- Keep behavior unchanged when moving logic between files.
