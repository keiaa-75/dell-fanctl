# Test fakes

Stand-ins for the hardware tools `dell-fanctl` uses, so the tests can run the script without touching real fans, sensors, or kernel modules.

## How they are used

A test calls `use_fakes` (from `tests/helpers.bash`) in its `setup()`. That:

- puts this folder first in `PATH`, so the script finds these fakes before the real `i8kfan` and `lsmod`
- points `HWMON_ROOT` at an empty folder in `$BATS_TEST_TMPDIR`, which `add_sensor` fills with fake sensors

Everything is created inside `$BATS_TEST_TMPDIR`, which bats deletes after each test.

## `i8kfan`

| Called as | Does |
|---|---|
| `i8kfan` | Prints the fan status: `FAKE_I8KFAN_STATUS`, or `-1 1` if unset or empty (no left fan, right fan present) |
| `i8kfan <left> <right>` | Appends `<left> <right>` as one line to `FAKE_I8KFAN_LOG` instead of setting any fan |

`fan_commands` prints that log, so a test can check which speeds were set.

## `lsmod`

Prints `FAKE_LSMOD_OUTPUT`, or `dell_smm_hwmon` if it isn't set.
Set `FAKE_LSMOD_OUTPUT=""` to pretend the module isn't loaded.

## Fake sensors

Not a file here, but part of the same setup. `add_sensor <name> <reading>...` creates a folder under `HWMON_ROOT` the way the kernel lays out
`/sys/class/hwmon`:

```
hwmon0/
├── name           e.g. coretemp or dell_smm
├── temp1_input    first reading, in millidegrees (60000 = 60°C)
└── temp2_input    second reading, and so on
```

Readings are written as given, so a test can pass something like `abc` to fake a broken sensor. The new folder's path is in `SENSOR_DIR` afterwards.

## Example

```bash
load helpers

setup() {
    use_fakes
}

@test "60°C sets the fans to high" {
    add_sensor coretemp 60000
    # ... run the script ...
    expect_equal "0 2" "$(fan_commands)"
}
```

## Adding a fake

Keep it small. It should print what the script reads from the real tool, and write down anything that would change the system instead of doing it.
Make it executable with `chmod +x`.