#!/bin/bash

json_write_config() {
    local json_content=$1
    cat <<< "$json_content" > "$is_config_json"
}

json_check_core_config() {
    json_check_core_config_with "$is_core_bin" "$is_config_json"
}

json_check_core_config_with() {
    local core_binary=$1 config_file=${2:-$is_config_json}

    "$core_binary" check -c "$config_file" -C "$is_conf_dir" > /dev/null 2>&1
}
