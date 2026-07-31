#!/bin/bash

managed_record() {
    local item_type=$1 item_value=$2 item_extra=$3
    if [[ -n $is_sh_dir && -d $is_sh_dir ]]; then
        printf '%s|%s|%s\n' "$item_type" "$item_value" "$item_extra" >> "$is_sh_dir/.install_manifest"
    fi
}
