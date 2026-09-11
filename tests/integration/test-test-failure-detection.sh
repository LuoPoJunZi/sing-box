#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
# Each child uses real production modules. BASH_ENV injects failures at the exact
# assertion or generation boundary without modifying any repository file.
cat > "$tmp_dir/fault.sh" << 'EOF'
jq() {
    case "${FAULT_MODE:-}" in
        assertion)
            for arg in "$@"; do
                [[ $arg != '.inbounds | length == 1' ]] || return 97
            done
            ;;
        generator)
            for arg in "$@"; do
                [[ $arg != protocol ]] || return 98
            done
            ;;
        reader)
            for arg in "$@"; do
                [[ $arg != -je ]] || return 99
            done
            ;;
    esac
    command jq "$@"
}
EOF
for mode in assertion generator reader; do
    if BASH_ENV="$tmp_dir/fault.sh" FAULT_MODE="$mode" bash tests/integration/test-node-config.sh > "$tmp_dir/output" 2>&1; then
        cat "$tmp_dir/output"
        echo "[test-failure-detection] masked $mode failure" >&2
        exit 1
    fi
    grep -q '\[node-config\] failed:' "$tmp_dir/output"
done

# Explicit local-core runs also verify the release test's generation assertions.
# Ordinary offline runs never download a core.
if [[ ${SING_BOX_CORE_BIN:-} ]]; then
    for mode in assertion generator; do
        if BASH_ENV="$tmp_dir/fault.sh" FAULT_MODE="$mode" bash tests/integration/test-sing-box-release.sh > "$tmp_dir/output" 2>&1; then
            echo "[test-failure-detection] release suite masked $mode failure" >&2
            exit 1
        fi
        grep -q 'production generation failed:' "$tmp_dir/output"
    done
fi
echo "[test-failure-detection] ok: assertion, generator and reader failures fail the suite"
