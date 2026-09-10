#!/bin/bash

# Parse all query fields with one jq invocation; preserve spaces, quotes and URLs.
# The private record separator is rejected instead of silently splitting values.
query_read_node() {
    local data field index value
    local fields=(is_protocol port uuid password username ss_method ss_password
        door_port door_addr net_type path host is_servername is_private_key is_short_id is_public_key)
    local values=() jq_options=()
    [[ ${OSTYPE:-} == msys* ]] && jq_options+=(-b)
    unset is_reality is_no_auto_tls is_tmp_https_port
    for field in "${fields[@]}"; do unset "$field"; done
    if ! data=$(jq "${jq_options[@]}" -je '
        [(.inbounds[0] | .type, .listen_port,
          (.users[0] | .uuid, .password, .username), .method, .password,
          .override_port, .override_address,
          (.transport | .type, .path, .headers.host),
          (.tls | .server_name, .reality.private_key, .reality.short_id[0])),
          ([.outbounds[]? | (.tag // "") | select(startswith("public_key_"))][0])]
        | map(if . == null then "" else tostring end)
        | if any(.[]; contains("\u001e")) then error("invalid field separator")
          else .[] + "\u001e" end
    ' "$1" 2> /dev/null); then
        return 1
    fi
    while IFS= read -r -d $'\x1e' value; do values+=("$value"); done <<< "$data"
    for index in "${!fields[@]}"; do
        field=${fields[$index]}
        [[ -n ${values[$index]} ]] && printf -v "$field" '%s' "${values[$index]}"
    done
    is_up_var_set=1
    if [[ ${is_private_key:-} ]]; then
        is_reality=1
        net_type+=reality
        is_public_key=${is_public_key#public_key_}
    fi
    return 0
}

# Read-side interpretation only: never generate credentials or configuration.
query_protocol_metadata() {
    get addr
    case $is_protocol in
        shadowsocks) net=ss ;;
        trojan) net=${net_type:-trojan} ;;
        tuic | hysteria2 | socks | direct) net=$is_protocol ;;
        vmess | vless) net=${net_type:-tcp} ;;
        *)
            err "无法识别协议: $is_config_file"
            return 1
            ;;
    esac
    if [[ ${is_reality:-} ]]; then
        net=reality
    elif [[ $net == http && ${host:-} ]]; then
        net=h2
    fi
}
