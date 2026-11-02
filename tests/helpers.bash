# Shared helpers for the bats tests. Loaded with: load helpers

# Fails the test and shows both values if they differ.
expect_equal() {
    if [[ "$2" != "$1" ]]; then
        echo "expected: '$1'"
        echo "got: '$2'"
        return 1
    fi
}

# Puts the fake i8kfan and lsmod first in PATH, and points the script
# at an empty fake hwmon folder. Call it from setup().
use_fakes() {
    PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
    HWMON_ROOT="$BATS_TEST_TMPDIR/hwmon"
    FAKE_I8KFAN_LOG="$BATS_TEST_TMPDIR/i8kfan.log"
    SENSOR_COUNT=0
    mkdir -p "$HWMON_ROOT"
    touch "$FAKE_I8KFAN_LOG"
    export PATH HWMON_ROOT FAKE_I8KFAN_LOG
}

# Adds a fake sensor. Its folder is in SENSOR_DIR afterwards.
# Usage: add_sensor <name> <reading>...
# Readings are written as given, in millidegrees like the kernel uses,
# e.g. 60000 for 60°C. Anything else can be passed to fake a bad reading.
add_sensor() {
    local name=$1 reading n=0
    shift
    SENSOR_DIR="$HWMON_ROOT/hwmon$SENSOR_COUNT"
    SENSOR_COUNT=$(( SENSOR_COUNT + 1 ))
    mkdir -p "$SENSOR_DIR"
    echo "$name" > "$SENSOR_DIR/name"
    for reading in "$@"; do
        n=$(( n + 1 ))
        echo "$reading" > "$SENSOR_DIR/temp${n}_input"
    done
}

# Prints every speed command the fake i8kfan received, one per line.
fan_commands() {
    cat "$FAKE_I8KFAN_LOG"
}