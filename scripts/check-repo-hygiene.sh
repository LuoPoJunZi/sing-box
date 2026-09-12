#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

while IFS= read -r path; do
    case $path in
        AGENTS.md | LOCAL_WORK_MEMORY.md | LOCAL_SING_BOX_BLOG.md | \
            docs/TEST_REPORT_*.md | tests/e2e/loopback-proxy.py | \
            .env | */.env | .env.* | */.env.* | \
            *.key | *.pem | *.crt | *.cer | *.csr | *.p12 | *.pfx | \
            .DS_Store | */.DS_Store | Thumbs.db | */Thumbs.db | Desktop.ini | */Desktop.ini | \
            .idea/* | */.idea/* | .vscode/* | */.vscode/* | \
            *.swp | *.swo | *.stackdump | *~ | \
            __pycache__/* | */__pycache__/* | *.pyc | *.pyo | \
            .pytest_cache/* | */.pytest_cache/* | .coverage | */.coverage | \
            .venv/* | */.venv/* | venv/* | */venv/* | coverage/* | */coverage/* | \
            htmlcov/* | */htmlcov/* | .cache/* | */.cache/* | tmp/* | */tmp/* | \
            dist/* | */dist/* | build/* | */build/* | out/* | */out/* | \
            *.log | *.pid | *.tmp | *.bak | *.tar | *.tar.gz | *.zip)
            if [[ $path == .env.example || $path == */.env.example ]]; then
                continue
            fi
            printf '[repo-hygiene] tracked local/generated file: %s\n' "$path"
            fail=1
            ;;
    esac
done < <(git ls-files)

if [[ $fail -ne 0 ]]; then
    echo "[repo-hygiene] failed"
    exit 1
fi

echo "[repo-hygiene] ok"
