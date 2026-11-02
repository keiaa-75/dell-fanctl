# Tests

Tests for dell-fanctl, written with [bats](https://github.com/bats-core/bats-core).

They never touch real fans, sensors or kernel modules. Everything runs against temporary files and the fakes in [`fakes/`](fakes/README.md), so they are safe to run on any machine, including the laptop being cooled.

## Running

Install `bats` once:

```bash
sudo apt install bats
```

Then, from the repository root:

```bash
bats tests/
```

To run a single file, pass it instead, for example `bats tests/config.bats`.

Each test prints 'ok' or 'not ok'. A failing test shows the line that failed and, for value checks, the expected and actual value.

## Files

| File | Tests | Covers |
|---|---|---|
| `parse-config.bats` | `lib/parse-config.sh` | Reading the config file: accepted lines, skipped lines, and lines that must never run as code |
| `config.bats` | `lib/config.sh` | Defaults, limits, rules between settings, and falling back to the defaults |
| `dell-fanctl.bats` | `src/dell-fanctl` | Fan speed decisions, sensor search, temperature readings, fan commands, and shutdown |
| `helpers.bash` | | Shared helpers, loaded with `load helpers` |
| `fakes/` | | Fake `i8kfan` and `lsmod`; see [`fakes/README.md`](fakes/README.md) |

## Helpers

| Helper | Does |
|---|---|
| `expect_equal <expected> <actual>` | Fails the test and shows both values if they differ |
| `use_fakes` | Puts the fakes first in `PATH` and sets up an empty fake sensor folder. Call it from `setup()` |
| `add_sensor <name> <reading>...` | Adds a fake sensor. Its folder is in `SENSOR_DIR` afterwards |
| `fan_commands` | Prints every speed the fake `i8kfan` was asked to set, one per line |

## Writing a test

- Write temporary files only to `$BATS_TEST_TMPDIR`. `bats` deletes it after each test.
- Use `run` when the code under test may exit, for example on an error, so the exit doesn't end the test. `run` puts the exit code in `status` and the output in `output`.
- Tests that start the whole script must stop it again, as `dell-fanctl.bats` does with `start_script` and `stop_script`.