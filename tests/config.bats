#!/usr/bin/env bats
# Tests for lib/config.sh. Uses temporary files only.

load helpers

setup() {
    source "$BATS_TEST_DIRNAME/../lib/parse-config.sh"
    source "$BATS_TEST_DIRNAME/../lib/config.sh"
    CONF="$BATS_TEST_TMPDIR/test.conf"
}

# Writes each argument as one line of the test config, then loads it.
# Everything load_config prints goes into OUTPUT.
load_test_config() {
    local line
    for line in "$@"; do
        echo "$line"
    done > "$CONF"
    load_config "$CONF" > "$BATS_TEST_TMPDIR/output" 2>&1
    OUTPUT=$(< "$BATS_TEST_TMPDIR/output")
}

expect_settings() {
    expect_equal "$1" "$TEMP_LOW"
    expect_equal "$2" "$TEMP_HIGH"
    expect_equal "$3" "$HYST_OFFSET"
    expect_equal "$4" "$POLL_INTERVAL"
}

expect_defaults() {
    expect_settings 20 55 10 5
}

# Expects the given errors, one per argument, followed by the fallback warning.
expect_fallback_with() {
    local expected line
    expected=$(
        for line in "$@" "WARNING: Invalid config; using defaults."; do
            echo "$line"
        done
    )
    expect_equal "$expected" "$OUTPUT"
    expect_defaults
}

# defaults

@test "missing config file gives the defaults silently" {
    load_config "$BATS_TEST_TMPDIR/missing.conf" > "$BATS_TEST_TMPDIR/output" 2>&1
    expect_equal "" "$(< "$BATS_TEST_TMPDIR/output")"
    expect_defaults
}

@test "empty config file gives the defaults silently" {
    load_test_config ''
    expect_equal "" "$OUTPUT"
    expect_defaults
}

# valid configs

@test "valid config is used" {
    load_test_config 'TEMP_LOW=30' 'TEMP_HIGH=70' 'HYST_OFFSET=5' 'POLL_INTERVAL=2'
    expect_equal "" "$OUTPUT"
    expect_settings 30 70 5 2
}

@test "settings not in the file keep their defaults" {
    load_test_config 'TEMP_HIGH=70'
    expect_settings 20 70 10 5
}

@test "skipped lines don't stop the rest of the config from being used" {
    load_test_config 'not a setting' 'TEMP_HIGH=70'
    expect_equal "WARNING: Unknown setting 'notasetting'; ignoring." "$OUTPUT"
    expect_settings 20 70 10 5
}

@test "values exactly at the limits are accepted" {
    load_test_config 'TEMP_LOW=10' 'TEMP_HIGH=85' 'HYST_OFFSET=10' 'POLL_INTERVAL=10'
    expect_equal "" "$OUTPUT"
    expect_settings 10 85 10 10
}

@test "lowest allowed values are accepted" {
    load_test_config 'TEMP_LOW=1' 'TEMP_HIGH=2' 'HYST_OFFSET=1' 'POLL_INTERVAL=1'
    expect_equal "" "$OUTPUT"
    expect_settings 1 2 1 1
}

# each rule falls back to the defaults when broken

@test "TEMP_LOW equal to TEMP_HIGH falls back to defaults" {
    load_test_config 'TEMP_LOW=50' 'TEMP_HIGH=50'
    expect_fallback_with "ERROR: TEMP_LOW (50) must be less than TEMP_HIGH (50)."
}

@test "TEMP_HIGH above 85 falls back to defaults" {
    load_test_config 'TEMP_HIGH=86'
    expect_fallback_with "ERROR: TEMP_HIGH must be at most 85°C (got: 86)."
}

@test "HYST_OFFSET of 0 falls back to defaults" {
    load_test_config 'HYST_OFFSET=0'
    expect_fallback_with "ERROR: HYST_OFFSET must be greater than 0 (got: 0)."
}

@test "TEMP_LOW below HYST_OFFSET falls back to defaults" {
    load_test_config 'TEMP_LOW=5' 'HYST_OFFSET=10'
    expect_fallback_with "ERROR: TEMP_LOW - HYST_OFFSET must be >= 0 (got: -5)."
}

@test "POLL_INTERVAL of 0 falls back to defaults" {
    load_test_config 'POLL_INTERVAL=0'
    expect_fallback_with "ERROR: POLL_INTERVAL must be greater than 0 (got: 0)."
}

@test "POLL_INTERVAL above 10 falls back to defaults" {
    load_test_config 'POLL_INTERVAL=11'
    expect_fallback_with "ERROR: POLL_INTERVAL must be at most 10s (got: 11)."
}

@test "one bad value resets the valid ones too" {
    load_test_config 'TEMP_LOW=30' 'TEMP_HIGH=90' 'POLL_INTERVAL=2'
    expect_fallback_with "ERROR: TEMP_HIGH must be at most 85°C (got: 90)."
}

@test "every broken rule is reported" {
    load_test_config 'TEMP_HIGH=100' 'POLL_INTERVAL=60'
    expect_fallback_with "ERROR: TEMP_HIGH must be at most 85°C (got: 100)." "ERROR: POLL_INTERVAL must be at most 10s (got: 60)."
}
