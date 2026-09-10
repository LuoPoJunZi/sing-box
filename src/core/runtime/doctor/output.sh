#!/bin/bash

runtime_doctor_ok() {
    msg "$(ui_success "[OK]") $*"
    ((ok++))
}

runtime_doctor_warn() {
    msg "$(ui_warn "[WARN]") $*"
    ((warn_count++))
}

runtime_doctor_fail() {
    msg "$(ui_error "[FAIL]") $*"
    ((fail++))
}

runtime_doctor_info() {
    msg "$(ui_muted "[INFO]") $*"
}

runtime_doctor_join_limited() {
    local limit=$1 count=0 shown=0 item="" output=""
    shift
    count=$#

    for item in "$@"; do
        ((shown++))
        if ((shown > limit)); then
            break
        fi
        if [[ $output ]]; then
            output="$output, $item"
        else
            output="$item"
        fi
    done

    if ((count > limit)); then
        output="$output, ...+$((count - limit))"
    fi

    echo "$output"
}
