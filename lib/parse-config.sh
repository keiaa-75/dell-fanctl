#!/usr/bin/env bash
# Reads NAME=number lines from a config file without running it.
# Numbers must be whole and 0 or higher; anything else is skipped.
# Usage: parse_config <file> <allowed name>...

is_allowed() {
    local name=$1 option
    shift
    for option in "$@"; do
        [[ "$name" == "$option" ]] && return 0
    done
    return 1
}

is_number() {
    [[ -n "$1" && "$1" != *[!0-9]* ]]
}

parse_config() {
    local file=$1
    shift
    local allowed=("$@")
    local line name value

    while IFS= read -r line || [[ -n "$line" ]]; do
        # remove comments and spaces
        line=${line%%#*}
        line=${line//[[:space:]]/}

        # skip empty lines
        [[ -z "$line" ]] && continue

        # split "NAME=value" at the first "="
        name=${line%%=*}
        value=${line#*=}

        if ! is_allowed "$name" "${allowed[@]}"; then
            echo "WARNING: Unknown setting '$name'; ignoring."
            continue
        fi

        if ! is_number "$value"; then
            echo "WARNING: $name must be a whole number (got: '$value'); ignoring."
            continue
        fi

        # base 10, so 08 is read as 8 rather than as octal
        printf -v "$name" '%d' "$(( 10#$value ))"
    done < "$file"
}
