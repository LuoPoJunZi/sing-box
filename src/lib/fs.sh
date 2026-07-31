#!/bin/bash

list_conf_json_names() {
    local file_filter="${1:-.json$}"
    find "$is_conf_dir" -maxdepth 1 -type f -printf '%f\n' 2> /dev/null |
        grep -E -i "$file_filter" |
        sed '/dynamic-port-.*-link/d' |
        head -233
}
