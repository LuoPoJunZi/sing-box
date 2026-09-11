#!/bin/bash

# Commit a main config or node replacement after validating the prospective set.
# File rollback is automatic on handled failures; services are changed by callers
# only after success. A failed rollback retains the recovery directory.
node_commit_config() (
    local kind=$1 content=$2 name=${3:-} previous=${4:-}
    local target old="" parent stage="" candidate_name lock="${is_config_json}.write-lock"
    local installed=0 committed=0 had_target=0 recovery_failed=0
    case $kind in
        main) target=$is_config_json ;;
        node)
            for candidate_name in "$name" "${previous:-$name}"; do
                [[ $candidate_name == *.json && $candidate_name != */* && $candidate_name != *\\* ]] || return 1
            done
            target="$is_conf_dir/$name"
            [[ $previous ]] && old="$is_conf_dir/$previous"
            ;;
        *) return 1 ;;
    esac
    if [[ ${is_dry_run:-} ]]; then
        msg "DRY-RUN: 将校验并替换配置 -> $target"
        return 0
    fi
    [[ -d $is_conf_dir && $is_conf_dir != / && ! -L $target && ! -d $target ]] || return 1
    [[ ! $old || (-f $old && ! -L $old) ]] || return 1
    [[ $kind != node || $target == "$old" || ! -e $target ]] || {
        warn "目标节点已存在，拒绝覆盖: $target"
        return 1
    }
    parent=${target%/*}
    [[ -d $parent && $parent != / ]] || return 1
    umask 077
    mkdir -- "$lock" 2> /dev/null || {
        warn "配置写入锁已存在，请确认没有并发写入: $lock"
        return 1
    }
    node_transaction_cleanup() {
        if [[ $installed == 1 && $committed != 1 ]]; then
            if [[ $had_target == 1 ]]; then
                mv -f -- "$stage/target.before" "$target" || recovery_failed=1
            else
                rm -f -- "$target" || recovery_failed=1
            fi
            if [[ $old && $old != "$target" ]]; then
                cp -p -- "$stage/old.before" "$old" || recovery_failed=1
            fi
        fi
        if [[ $recovery_failed == 1 ]]; then
            warn "自动恢复失败，请保留并检查恢复目录: $stage"
        elif [[ $stage ]]; then
            rm -rf -- "$stage"
        fi
        rmdir -- "$lock"
    }
    trap node_transaction_cleanup EXIT
    trap 'exit 1' HUP INT TERM
    stage=$(mktemp -d "$parent/.config-txn.XXXXXX") || return 1
    mkdir -- "$stage/conf" || return 1
    local config_file
    for config_file in "$is_conf_dir"/*.json; do
        [[ -e $config_file ]] || continue
        [[ -f $config_file && ! -L $config_file ]] || return 1
        if [[ $kind == node && ($config_file == "$old" || $config_file == "$target") ]]; then continue; fi
        cp -p -- "$config_file" "$stage/conf/" || return 1
    done
    if [[ $kind == main ]]; then
        printf '%s\n' "$content" > "$stage/main.json" || return 1
    else
        [[ -f $is_config_json && ! -L $is_config_json ]] || return 1
        cp -p -- "$is_config_json" "$stage/main.json" || return 1
        printf '%s\n' "$content" > "$stage/conf/$name" || return 1
    fi
    local candidate="$stage/main.json"
    [[ $kind == node ]] && candidate="$stage/conf/$name"
    jq -e 'type == "object"' "$candidate" > /dev/null || return 1
    "$is_core_bin" check -c "$stage/main.json" -C "$stage/conf" > "$stage/check.log" 2>&1 || {
        warn "候选配置未通过核心校验，现有配置保持不变"
        cat -- "$stage/check.log" >&2
        return 1
    }
    if [[ -e $target ]]; then
        cp -p -- "$target" "$stage/target.before" || return 1
        chmod --reference="$target" "$candidate" || return 1
        had_target=1
    fi
    if [[ $old && $old != "$target" ]]; then cp -p -- "$old" "$stage/old.before" || return 1; fi
    # The candidate is on the target filesystem. Never delete the old file first.
    installed=1
    mv -f -- "$candidate" "$target" || return 1
    if [[ $old && $old != "$target" ]]; then rm -- "$old" || return 1; fi
    committed=1
    return 0
)
