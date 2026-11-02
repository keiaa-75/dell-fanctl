#!/usr/bin/env bats
# Tests for src/dell-fanctld. Uses the fakes in tests/fakes only:
# no real fans, sensors or kernel modules are touched.

load helpers

setup() {
    use_fakes
    SCRIPT="$BATS_TEST_DIRNAME/../src/dell-fanctld"
    FANCTL_LIB="$BATS_TEST_DIRNAME/../lib"
    FANCTL_CONF="$BATS_TEST_TMPDIR/missing.conf"
    export FANCTL_LIB FANCTL_CONF

    # loads the functions without starting the fan loop
    source "$SCRIPT"
    set_defaults
}

teardown() {
    # stop the script if a test failed before stopping it
    if [[ -n "$SCRIPT_PID" ]]; then
        kill "$SCRIPT_PID" 2> /dev/null
        wait "$SCRIPT_PID" 2> /dev/null
    fi
    return 0
}

# Starts the whole script in the background. Its output goes to OUTPUT_FILE.
start_script() {
    OUTPUT_FILE="$BATS_TEST_TMPDIR/output"
    bash "$SCRIPT" > "$OUTPUT_FILE" 2>&1 &
    SCRIPT_PID=$!
}

# Stops the script with SIGTERM, like systemd does.
# Afterwards EXIT_CODE holds its exit code and STOP_TIME the seconds it took.
stop_script() {
    local start=$SECONDS
    kill -TERM "$SCRIPT_PID"
    wait "$SCRIPT_PID"
    EXIT_CODE=$?
    STOP_TIME=$(( SECONDS - start ))
    SCRIPT_PID=
}

# Waits up to 5 seconds until the i8kfan has received a command.
wait_for_fan_command() {
    local i
    for i in $(seq 50); do
        [[ -s "$FAKE_I8KFAN_LOG" ]] && return 0
        sleep 0.1
    done
    echo "the script set no fan speed within 5 seconds"
    return 1
}

# Prints the speed next_speed picks, so the tests can compare it.
speed_for() {
    next_speed "$1" "$2"
    echo "$NEXT_SPEED"
}

# next_speed, with the defaults TEMP_LOW=20, TEMP_HIGH=55, HYST_OFFSET=10

@test "reaching TEMP_HIGH sets high from any speed" {
    expect_equal 2 "$(speed_for 55 0)"
    expect_equal 2 "$(speed_for 55 1)"
    expect_equal 2 "$(speed_for 55 2)"
}

@test "high stays high until HYST_OFFSET below TEMP_HIGH" {
    expect_equal 2 "$(speed_for 54 2)"
    expect_equal 2 "$(speed_for 45 2)"
}

@test "high drops to low once HYST_OFFSET below TEMP_HIGH" {
    expect_equal 1 "$(speed_for 44 2)"
}

@test "reaching TEMP_LOW turns the fans on at low" {
    expect_equal 1 "$(speed_for 20 0)"
    expect_equal 1 "$(speed_for 54 0)"
}

@test "low stays low until HYST_OFFSET below TEMP_LOW" {
    expect_equal 1 "$(speed_for 19 1)"
    expect_equal 1 "$(speed_for 10 1)"
}

@test "low turns off once HYST_OFFSET below TEMP_LOW" {
    expect_equal 0 "$(speed_for 9 1)"
}

@test "off stays off below TEMP_LOW" {
    expect_equal 0 "$(speed_for 19 0)"
}

@test "first reading always picks a known speed" {
    expect_equal 0 "$(speed_for 15 -1)"
    expect_equal 1 "$(speed_for 30 -1)"
    expect_equal 2 "$(speed_for 60 -1)"
}

# sensor search

@test "coretemp is preferred when it comes before dell_smm" {
    add_sensor coretemp 60000
    local coretemp=$SENSOR_DIR
    add_sensor dell_smm 40000
    find_temp_input
    expect_equal "$coretemp" "$HWMON_PATH"
}

@test "coretemp is preferred when it comes after dell_smm" {
    add_sensor dell_smm 40000
    add_sensor coretemp 60000
    find_temp_input
    expect_equal "$SENSOR_DIR" "$HWMON_PATH"
}

@test "dell_smm is used when there is no coretemp" {
    add_sensor nvme 30000
    add_sensor dell_smm 40000
    find_temp_input
    expect_equal "$SENSOR_DIR" "$HWMON_PATH"
}

@test "no suitable sensor is an error" {
    add_sensor nvme 30000
    run find_temp_input
    expect_equal 1 "$status"
    expect_equal "ERROR: No suitable temperature sensor found." "$output"
}

# temperature readings

@test "the hottest reading of the sensor is used" {
    add_sensor coretemp 45000 60000 52000
    find_temp_input
    get_temp
    expect_equal 60 "$TEMP"
}

@test "bad readings are ignored when another reading is valid" {
    add_sensor coretemp abc 60000 -5000
    find_temp_input
    get_temp
    expect_equal 60 "$TEMP"
}

@test "unreadable temperature is skipped with a warning" {
    add_sensor coretemp abc
    find_temp_input
    run get_temp
    expect_equal 1 "$status"
    expect_equal "WARNING: Could not read temperature; skipping iteration." "$output"
}

@test "implausible temperature is skipped with a warning" {
    add_sensor coretemp 106000
    find_temp_input
    run get_temp
    expect_equal 1 "$status"
    expect_equal "WARNING: Implausible temperature reading (106°C); skipping iteration." "$output"
}

# fans

@test "missing kernel module is an error" {
    FAKE_LSMOD_OUTPUT=""
    export FAKE_LSMOD_OUTPUT
    run check_deps
    expect_equal 1 "$status"
    expect_equal "ERROR: dell_smm_hwmon not loaded." "$output"
}

@test "a fan reported as -1 gets speed 0" {
    check_deps
    find_fans
    CURRENT_SPEED=-1
    set_fan_speed 2 > /dev/null
    expect_equal "0 2" "$(fan_commands)"
}

@test "both fans get the speed when both are present" {
    FAKE_I8KFAN_STATUS="1 1"
    export FAKE_I8KFAN_STATUS
    check_deps
    find_fans
    CURRENT_SPEED=-1
    set_fan_speed 2 > /dev/null
    expect_equal "2 2" "$(fan_commands)"
}

@test "no command is sent when the speed doesn't change" {
    check_deps
    find_fans
    CURRENT_SPEED=2
    set_fan_speed 2 > /dev/null
    expect_equal "" "$(fan_commands)"
}

# the whole script

@test "SIGTERM sets the fans to high once and exits quickly" {
    add_sensor coretemp 30000
    start_script
    wait_for_fan_command
    stop_script

    expect_equal 0 "$EXIT_CODE"
    expect_equal "0 1 | 0 2" "$(fan_commands | paste -sd '|' | sed 's/|/ | /g')"
    expect_equal 1 "$(grep -c "Shutting down" "$OUTPUT_FILE")"
    [[ "$STOP_TIME" -le 1 ]] || { echo "took ${STOP_TIME}s to stop"; return 1; }
}

@test "a cold first reading turns the fans off" {
    add_sensor coretemp 15000
    start_script
    wait_for_fan_command
    stop_script
    expect_equal "0 0" "$(fan_commands | head -1)"
}