#!/bin/bash

json_write_config() {
    local json_content=$1
    cat <<< "$json_content" > "$is_config_json"
}

json_check_core_config() {
    $is_core_bin check -c "$is_config_json" -C "$is_conf_dir" > /dev/null 2>&1
}
