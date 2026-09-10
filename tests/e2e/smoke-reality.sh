#!/usr/bin/env bash
set -euo pipefail

SB_BIN="${SB_BIN:-sb}"
CONF_DIR="${CONF_DIR:-/etc/sing-box/conf}"
CORE_BIN="${CORE_BIN:-/etc/sing-box/bin/sing-box}"

if ! command -v "$SB_BIN" > /dev/null 2>&1; then
    echo "[smoke-reality] command not found: $SB_BIN"
    exit 1
fi

if [[ ! -d "$CONF_DIR" ]]; then
    echo "[smoke-reality] conf dir not found: $CONF_DIR"
    exit 1
fi

if [[ ! -x "$CORE_BIN" ]]; then
    echo "[smoke-reality] core bin not found: $CORE_BIN"
    exit 1
fi

tmp_before="$(mktemp)"
tmp_after="$(mktemp)"
created_auto=""
created_manual=""
manual_sni="www.cloudflare.com"

cleanup() {
    if [[ -n "$created_manual" ]]; then "$SB_BIN" del "$created_manual" > /dev/null 2>&1 || true; fi
    if [[ -n "$created_auto" ]]; then "$SB_BIN" del "$created_auto" > /dev/null 2>&1 || true; fi
    rm -f "$tmp_before" "$tmp_after"
}
trap cleanup EXIT

list_reality_files() {
    find "$CONF_DIR" -maxdepth 1 -type f -name '*REALITY*.json' -printf '%f\n' | sort
}

echo "[smoke-reality] snapshot before"
list_reality_files > "$tmp_before"

echo "[smoke-reality] add reality with auto sni"
"$SB_BIN" add reality auto auto auto > /dev/null
list_reality_files > "$tmp_after"
created_auto="$(grep -Fxv -f "$tmp_before" "$tmp_after" | head -n 1 || true)"
if [[ -z "$created_auto" ]]; then
    echo "[smoke-reality] failed to detect created auto reality config"
    exit 1
fi

echo "[smoke-reality] verify auto sni and url: $created_auto"
"$SB_BIN" info "$created_auto" > /dev/null
url_auto="$("$SB_BIN" url "$created_auto" 2> /dev/null || true)"
if ! grep -q 'sni=' <<< "$url_auto"; then
    echo "[smoke-reality] url missing sni for $created_auto"
    exit 1
fi
if ! grep -Eq 'sid=[0-9a-fA-F]{8}' <<< "$url_auto"; then
    echo "[smoke-reality] url missing valid short id for $created_auto"
    exit 1
fi
auto_sni="$(jq -r '.inbounds[0].tls.server_name // empty' "$CONF_DIR/$created_auto")"
if [[ -z "$auto_sni" ]]; then
    echo "[smoke-reality] auto sni is empty in config: $created_auto"
    exit 1
fi
auto_short_id="$(jq -r '.inbounds[0].tls.reality.short_id[0] // empty' "$CONF_DIR/$created_auto")"
if [[ ! $auto_short_id =~ ^[0-9a-fA-F]{8}$ ]]; then
    echo "[smoke-reality] config has invalid short id: $created_auto"
    exit 1
fi

echo "[smoke-reality] add reality with manual sni=$manual_sni"
cp -f "$tmp_after" "$tmp_before"
"$SB_BIN" add reality auto auto "$manual_sni" > /dev/null
list_reality_files > "$tmp_after"
created_manual="$(grep -Fxv -f "$tmp_before" "$tmp_after" | head -n 1 || true)"
if [[ -z "$created_manual" ]]; then
    echo "[smoke-reality] failed to detect created manual reality config"
    exit 1
fi

echo "[smoke-reality] verify manual sni and url: $created_manual"
"$SB_BIN" info "$created_manual" > /dev/null
url_manual="$("$SB_BIN" url "$created_manual" 2> /dev/null || true)"
if ! grep -q "sni=$manual_sni" <<< "$url_manual"; then
    echo "[smoke-reality] manual url sni mismatch for $created_manual"
    exit 1
fi
if ! grep -Eq 'sid=[0-9a-fA-F]{8}' <<< "$url_manual"; then
    echo "[smoke-reality] manual url missing valid short id for $created_manual"
    exit 1
fi
cfg_manual_sni="$(jq -r '.inbounds[0].tls.server_name // empty' "$CONF_DIR/$created_manual")"
if [[ "$cfg_manual_sni" != "$manual_sni" ]]; then
    echo "[smoke-reality] manual config sni mismatch: got=$cfg_manual_sni expected=$manual_sni"
    exit 1
fi

echo "[smoke-reality] sing-box config check"
"$CORE_BIN" check -c /etc/sing-box/config.json -C "$CONF_DIR" > /dev/null

echo "[smoke-reality] pass"
