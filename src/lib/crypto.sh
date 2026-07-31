#!/bin/bash

get_uuid() {
    tmp_uuid=$(cat /proc/sys/kernel/random/uuid)
}

get_pbk() {
    mapfile -t is_tmp_pbk < <("$is_core_bin" generate reality-keypair | sed 's/.*:[[:space:]]*//')
    is_public_key=${is_tmp_pbk[1]}
    is_private_key=${is_tmp_pbk[0]}
}

get_reality_short_id() {
    if [[ ${is_short_id:-} =~ ^[0-9a-fA-F]{1,8}$ ]]; then
        return
    fi

    is_short_id=$(openssl rand -hex 4 2> /dev/null || true)
    if [[ ! $is_short_id =~ ^[0-9a-fA-F]{8}$ ]]; then
        is_short_id=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
}
