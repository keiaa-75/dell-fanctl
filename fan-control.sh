#!/bin/bash

TEMP_LOW=20
TEMP_HIGH=55
TEMP_HIGH_HYST=40
POLL_INTERVAL=5

check_deps() {
    I8KFAN=$(command -v i8kfan) || { echo "ERROR: i8kfan not found."; exit 1; }
    lsmod | grep -q dell_smm_hwmon || { echo "ERROR: dell_smm_hwmon not loaded."; exit 1; }
}

find_temp_input() {
    local hwmon name

    for hwmon in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hwmon/name" 2>/dev/null)

        case "$name" in
            coretemp|dell_smm)
                HWMON_PATH="$hwmon"
                return ;;
        esac
    done

    echo "ERROR: No suitable temperature sensor found."; exit 1
}

find_fans() {
    local left right
    read -r left right < <($I8KFAN)
    LEFT_FAN=$(( left != -1 ))
    RIGHT_FAN=$(( right != -1 ))
}

get_temp () {
    TEMP=$(cat "$HWMON_PATH"/temp*_input 2>/dev/null | sort -n | tail -1)
    TEMP=$(( TEMP / 1000 ))
}

set_fan_speed() {
    local speed=$1

    if [[ "$speed" -ne "$CURRENT_SPEED" ]]; then
        local left_arg=$(( LEFT_FAN ? speed : 0 ))
        local right_arg=$(( RIGHT_FAN ? speed : 0 ))
        $I8KFAN "$left_arg" "$right_arg"
        CURRENT_SPEED=$speed
    fi
}

main() {
    check_deps
    find_temp_input
    find_fans

    local CURRENT_SPEED=-1

    while true; do
        get_temp

        if [[ "$TEMP" -ge "$TEMP_HIGH" ]];                                      then set_fan_speed 2
        elif [[ "$TEMP" -lt "$TEMP_HIGH_HYST" && "$CURRENT_SPEED" -eq 2 ]];     then set_fan_speed 1
        elif [[ "$TEMP" -ge "$TEMP_LOW" && "$CURRENT_SPEED" -lt 1 ]];           then set_fan_speed 1
        elif [[ "$TEMP" -lt "$TEMP_LOW" ]];                                     then set_fan_speed 0
        fi

        sleep "$POLL_INTERVAL"
    done
}

main
