#!/usr/bin/env bats
# Tests for lib/parse-config.sh. Uses temporary files only.

setup() {
    source "$BATS_TEST_DIRNAME/../lib/parse-config.sh"
    CONF="$BATS_TEST_TMPDIR/test.conf"
    TEMP_HIGH=55
    TEMP_LOW=20
}

# Writes each argument as one line of the test config, then parses it.
# Everything the parser prints, including errors, goes into OUTPUT.
parse() {
    printf '%s
' "$@" > "$CONF"
    run_parser
}

run_parser() {
    parse_config "$CONF" TEMP_HIGH TEMP_LOW > "$BATS_TEST_TMPDIR/output" 2>&1
    OUTPUT=$(< "$BATS_TEST_TMPDIR/output")
}

# Fails the test and shows both values if they differ.
expect_equal() {
    if [[ "$2" != "$1" ]]; then
        echo "expected: '$1'"
        echo "got:      '$2'"
        return 1
    fi
}

# accepted values

@test "plain value is read" {
    parse 'TEMP_HIGH=60'
    expect_equal 60 "$TEMP_HIGH"
}

@test "spaces around = are allowed" {
    parse 'TEMP_HIGH = 60'
    expect_equal 60 "$TEMP_HIGH"
}

@test "comment after a value is ignored" {
    parse 'TEMP_HIGH=60 # a note'
    expect_equal 60 "$TEMP_HIGH"
}

@test "leading zero is read as base 10" {
    parse 'TEMP_HIGH=08'
    expect_equal 8 "$TEMP_HIGH"
}

@test "zero is accepted" {
    parse 'TEMP_HIGH=0'
    expect_equal 0 "$TEMP_HIGH"
}

@test "several settings are read" {
    parse 'TEMP_HIGH=60' 'TEMP_LOW=30'
    expect_equal 60 "$TEMP_HIGH"
    expect_equal 30 "$TEMP_LOW"
}

@test "last value wins when a setting repeats" {
    parse 'TEMP_HIGH=60' 'TEMP_HIGH=70'
    expect_equal 70 "$TEMP_HIGH"
}

@test "last line without a newline is read" {
    printf 'TEMP_HIGH=60' > "$CONF"
    run_parser
    expect_equal 60 "$TEMP_HIGH"
}

# lines that are skipped silently

@test "comments and blank lines are skipped silently" {
    parse '# just a comment' '' '   '
    expect_equal 55 "$TEMP_HIGH"
    expect_equal "" "$OUTPUT"
}

# values that are skipped with a warning

@test "negative value is skipped with a warning" {
    parse 'TEMP_HIGH=-5'
    expect_equal 55 "$TEMP_HIGH"
    expect_equal "WARNING: TEMP_HIGH must be a whole number (got: '-5'); ignoring." "$OUTPUT"
}

@test "decimal value is skipped with a warning" {
    parse 'TEMP_HIGH=6.5'
    expect_equal 55 "$TEMP_HIGH"
    expect_equal "WARNING: TEMP_HIGH must be a whole number (got: '6.5'); ignoring." "$OUTPUT"
}

@test "empty value is skipped with a warning" {
    parse 'TEMP_HIGH='
    expect_equal 55 "$TEMP_HIGH"
    expect_equal "WARNING: TEMP_HIGH must be a whole number (got: ''); ignoring." "$OUTPUT"
}

@test "value with a second = is skipped with a warning" {
    parse 'TEMP_HIGH=60=70'
    expect_equal 55 "$TEMP_HIGH"
    expect_equal "WARNING: TEMP_HIGH must be a whole number (got: '60=70'); ignoring." "$OUTPUT"
}

# names that are skipped with a warning

@test "misspelled setting is skipped with a warning" {
    parse 'POLL_INTEREVAL=1'
    expect_equal "WARNING: Unknown setting 'POLL_INTEREVAL'; ignoring." "$OUTPUT"
}

@test "setting outside the allowed list is skipped with a warning" {
    local path_before=$PATH path_after
    parse 'PATH=1'
    path_after=$PATH
    PATH=$path_before
    expect_equal "$path_before" "$path_after"
    expect_equal "WARNING: Unknown setting 'PATH'; ignoring." "$OUTPUT"
}

# lines that would run code if the file were sourced

@test "command line does not run" {
    parse "touch $BATS_TEST_TMPDIR/marker"
    [[ ! -e "$BATS_TEST_TMPDIR/marker" ]]
}

@test "command substitution does not run" {
    parse "TEMP_HIGH=\$(touch $BATS_TEST_TMPDIR/marker)"
    [[ ! -e "$BATS_TEST_TMPDIR/marker" ]]
    expect_equal 55 "$TEMP_HIGH"
}