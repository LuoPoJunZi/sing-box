#!/usr/bin/env bash
set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
count=${BENCH_NODES:-20}
[[ $count =~ ^[1-9][0-9]*$ && $count -le 1000 ]] || exit 1
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
is_conf_dir="$tmp_dir/conf"
mkdir -p "$is_conf_dir"
for ((i = 0; i < count; i++)); do
    jq -n --argjson port "$((30000 + i))" '
      {inbounds:[{type:"vless",listen_port:$port,users:[{uuid:"test"}],
        tls:{enabled:true,server_name:"example.com",reality:{enabled:true,
          private_key:"private",handshake:{server:"example.com"},short_id:["0123abcd"]}}}],
       outbounds:[{tag:"public_key_test",type:"direct"}]}
    ' > "$is_conf_dir/$i.json"
done
if [[ ${1:-} ]]; then
    # Read a trusted local baseline commit; never execute remote content.
    git cat-file -e "$1:src/core/runtime/doctor.sh"
    . <(git show "$1:src/core/runtime/doctor.sh")
else
    . src/core/runtime/doctor.sh
fi
msg() { :; }
runtime_doctor_info() { :; }
runtime_doctor_ok() { :; }
runtime_doctor_warn() { :; }
runtime_doctor_fail() { :; }
runtime_doctor_port_listening() { return 0; }
jq() {
    printf '.\n' >> "$tmp_dir/jq-calls"
    command jq "$@"
}
start=$EPOCHREALTIME
set +e # Runtime diagnostics intentionally run without shell-wide errexit.
runtime_doctor_client_compat
runtime_doctor_reality
set -e
end=$EPOCHREALTIME
calls=$(wc -l < "$tmp_dir/jq-calls")
awk -v start="$start" -v end="$end" -v count="$count" -v calls="$calls" \
    'BEGIN {printf "nodes=%d jq_calls=%d seconds=%.3f\n", count, calls, end-start}'
