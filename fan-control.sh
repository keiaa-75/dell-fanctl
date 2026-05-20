#!/usr/bin/env bash

# script defaults
TEMP_LOW=20
TEMP_HIGH=55
HYST_OFFSET=10
POLL_INTERVAL=5

# fetch custom config, if any
FANCTL_CONF=/usr/local/etc/dell-fanctl.conf
[[ -f "$FANCTL_CONF" ]] && source "$FANCTL_CONF"

validate_config() {
    local ok=1

    # ensure all values are integers
    for var in TEMP_LOW TEMP_HIGH HYST_OFFSET POLL_INTERVAL; do
        if ! [[ "${!var}" =~ ^-?[0-9]+$ ]]; then
            echo "ERROR: $var must be an integer (got: '${!var}')."
            ok=0
        fi
    done

    # bail early if any are non-numeric; further checks would be meaningless
    [[ "$ok" -eq 1 ]] || exit 1

    if [[ "$TEMP_LOW" -ge "$TEMP_HIGH" ]]; then
        echo "ERROR: TEMP_LOW ($TEMP_LOW) must be less than TEMP_HIGH ($TEMP_HIGH)."
        ok=0
    fi

    if [[ "$HYST_OFFSET" -le 0 ]]; then
        echo "ERROR: HYST_OFFSET must be greater than 0 (got: $HYST_OFFSET)."
        ok=0
    fi

    if [[ "$(( TEMP_LOW - HYST_OFFSET ))" -lt 0 ]]; then
        echo "ERROR: TEMP_LOW - HYST_OFFSET must be >= 0 (got: $(( TEMP_LOW - HYST_OFFSET )))."
        ok=0
    fi

    if [[ "$POLL_INTERVAL" -le 0 ]]; then
        echo "ERROR: POLL_INTERVAL must be greater than 0 (got: $POLL_INTERVAL)."
        ok=0
    fi

    [[ "$ok" -eq 1 ]] || exit 1
}

check_deps() {
    # i8kfan is used to set fan speeds
    # dell_smm_hwmon exposes the interface
    I8KFAN=$(command -v i8kfan) || { echo "ERROR: i8kfan not found."; exit 1; }
    lsmod | grep -q dell_smm_hwmon || { echo "ERROR: dell_smm_hwmon not loaded."; exit 1; }
}

find_temp_input() {
    local hwmon name

    for hwmon in /sys/class/hwmon/hwmon*; do
        name=$(cat "$hwmon/name" 2>/dev/null)

        case "$name" in
            coretemp)
                # coretemp is preferred
                # no need to look further
                HWMON_PATH="$hwmon"
                return ;;
            dell_smm)
                # acceptable fallback
                # keep looping in case coretemp appears later
                HWMON_PATH="$hwmon" ;;
        esac
    done

    [[ -n "$HWMON_PATH" ]] || { echo "ERROR: No suitable temperature sensor found."; exit 1; }
}

find_fans() {
    local left right
    # i8kfan outputs two values
    # absent fans are reported as -1
    read -r left right < <($I8KFAN)
    LEFT_FAN=$(( left != -1 ))
    RIGHT_FAN=$(( right != -1 ))
}

get_temp() {
    local raw
    raw=$(cat "$HWMON_PATH"/temp*_input 2>/dev/null | sort -n | tail -1)

    # validate the reading before using it
    if ! [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "WARNING: Could not read temperature; skipping iteration."
        return 1
    fi

    local celsius=$(( raw / 1000 ))

    # sanity check: reject implausible values
    if [[ "$celsius" -lt 0 || "$celsius" -gt 105 ]]; then
        echo "WARNING: Implausible temperature reading (${celsius}°C); skipping iteration."
        return 1
    fi

    TEMP=$celsius
}

set_fan_speed() {
    local speed=$1

    # only issue command if speed is actually changing
    if [[ "$speed" -ne "$CURRENT_SPEED" ]]; then
        local left_arg=$(( LEFT_FAN ? speed : 0 ))
        local right_arg=$(( RIGHT_FAN ? speed : 0 ))
        $I8KFAN "$left_arg" "$right_arg"
        CURRENT_SPEED=$speed
    fi
}

main() {
    validate_config
    check_deps
    find_temp_input
    find_fans

    # set a safe speed on ext before BIOS takes back control
    trap 'set_fan_speed 1; exit 0' SIGTERM EXIT

    local CURRENT_SPEED=-1

    while true; do
        # skip fan control for this iteration on a bad temperature read
        if get_temp; then
            if [[ "$TEMP" -ge "$TEMP_HIGH" ]];                                                        then set_fan_speed 2
            elif [[ "$TEMP" -lt "$(( TEMP_HIGH - HYST_OFFSET ))" && "$CURRENT_SPEED" -eq 2 ]];        then set_fan_speed 1
            elif [[ "$TEMP" -ge "$TEMP_LOW" && "$CURRENT_SPEED" -lt 1 ]];                             then set_fan_speed 1
            elif [[ "$TEMP" -lt "$(( TEMP_LOW - HYST_OFFSET ))" && "$CURRENT_SPEED" -eq 1 ]];         then set_fan_speed 0
            fi
        fi

        sleep "$POLL_INTERVAL"
    done
}

main
