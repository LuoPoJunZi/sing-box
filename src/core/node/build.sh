#!/bin/bash

# Pure serialization: all dynamic strings are jq arguments, never jq source.
# Consumes the normalized write context; prints JSON and does not touch the system.
node_build_config() {
    MSYS2_ARG_CONV_EXCL='*' jq -n \
        --arg tag "$is_config_name" --arg protocol "$is_protocol" \
        --arg listen "${is_listen:-::}" --arg port "$port" \
        --arg net "$net" --arg lower "$is_lower" \
        --arg uuid "${uuid:-}" --arg password "${password:-}" \
        --arg user "${is_socks_user:-}" --arg pass "${is_socks_pass:-}" \
        --arg method "${ss_method:-}" --arg ss_password "${ss_password:-}" \
        --arg dest "${door_addr:-}" --arg dest_port "${door_port:-0}" \
        --arg host "${host:-}" --arg path "${path:-}" \
        --arg key "$is_tls_key" --arg cert "$is_tls_cer" \
        --arg sni "${is_servername:-}" --arg private "${is_private_key:-}" \
        --arg public "${is_public_key:-}" --arg sid "${is_short_id:-}" '
        def tls: {enabled:true, key_path:$key, certificate_path:$cert};
        def transport:
            {type: (if $net == "h2" then "http" else $net end)}
            + (if $host != "" and (($lower | contains("tls")) or $lower == "cftunnel")
               then {path:$path, headers:{host:$host}} else {} end)
            + (if $net == "ws" then {early_data_header_name:"Sec-WebSocket-Protocol"} else {} end);
        {
            inbounds: [
                {tag:$tag, type:$protocol, listen:$listen, listen_port:($port | tonumber)}
                + (if $protocol == "shadowsocks" then {method:$method, password:$ss_password}
                   elif $protocol == "direct" then {override_address:$dest, override_port:($dest_port | tonumber)}
                   elif $protocol == "socks" then {users:[{username:$user, password:$pass}]}
                   elif $protocol == "trojan" or $protocol == "hysteria2" then {users:[{password:$password}]}
                   elif $protocol == "tuic" then {users:[{uuid:$uuid, password:$password}], congestion_control:"bbr"}
                   else {users:[{uuid:$uuid}]} end)
                + (if $net == "reality" then
                     {tls:{enabled:true, server_name:$sni, reality:{enabled:true,
                       handshake:{server:$sni, server_port:443}, private_key:$private, short_id:[$sid]}}}
                     + (if $lower | contains("http") then {transport:{type:"http"}}
                        else {users:[{uuid:$uuid, flow:"xtls-rprx-vision"}]} end)
                   elif $net == "tuic" or $net == "hysteria2" then {tls:(tls + {alpn:["h3"]})}
                   elif $net == "quic" then {tls:(tls + {alpn:["h3"]}), transport:{type:"quic"}}
                   elif $net == "trojan" then {tls:tls}
                   elif $net == "h2" then {tls:tls, transport:transport}
                   elif $net == "ws" or $net == "http" or $net == "httpupgrade" then {transport:transport}
                   else {} end)
            ]
        }
        + (if $net == "reality" then {outbounds:[{type:"direct"}, {tag:("public_key_" + $public), type:"direct"}]} else {} end)
    '
}
