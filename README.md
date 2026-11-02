# dell-fanctl

A minimal, reliable fan control setup for Dell laptops on Linux, bypassing the broken BIOS fan control that keeps fans silent until relatively high temperatures.

Tested on: Latitude 5300 and Vostro 3468. Likely works on other Dell laptops that use the `dell-smm-hwmon` (i8k) kernel module.

## The Problem

On many Dell laptops, the BIOS fan control is overly conservative. It keeps fans completely off until the CPU reaches 70°C or higher.

This project takes a simpler approach: disable BIOS fan control at boot, then run a plain bash loop that reads CPU temperature and sets fan speed accordingly via `i8kfan`.

## Stack

- `dell-smm-hwmon` — kernel module that exposes the Dell SMM interface to userspace
- [`dell-bios-fan-control`](https://github.com/TomFreudenberg/dell-bios-fan-control) — disables BIOS fan control at boot so the OS can take over
- `i8kfan` (from `i8kutils`) — the actual command our script uses to set fan speeds
- `dell-fanctl` — our loop that reads temperatures and decides what speed to set automatically

## Installation

The installer is being rewritten as a single `install.sh` that downloads and sets up everything. Until it lands, install from a release that still has a Makefile (v2.1.0 or earlier) by following the README in that release.

## Configuration

To customize behavior, edit `/usr/local/etc/dell-fanctl.conf`. The script falls back to built-in defaults if the file is absent, so this is optional.

```bash
TEMP_LOW=20     # fan runs at low speed above this (°C)
TEMP_HIGH=55    # fan runs at max above this (°C, at most 85)
HYST_OFFSET=10  # how far temp must drop before stepping down
POLL_INTERVAL=5 # how often to check temperature (seconds, 1 to 10)
```

Fan speed steps down with hysteresis: it won't drop from max to low until the temperature falls `HYST_OFFSET` degrees below `TEMP_HIGH`, and won't turn off entirely until it falls `HYST_OFFSET` degrees below `TEMP_LOW`.

If any value is invalid or outside its limit, the script logs an error and uses the built-in defaults for all settings.

## Development

The tests use [bats](https://github.com/bats-core/bats-core) and never touch real fans, sensors or kernel modules, so they are safe to run on the laptop itself:

```bash
sudo apt install bats
bats tests/
```

See [`tests/README.md`](tests/README.md) for what the tests cover and how to write new ones.

## Notes

- If `i8kfan` returns `-1` for the left fan, your laptop likely only has one physical fan. This is normal.
- If you use `i8kmon`, disable it. It will conflict with `dell-fanctl`.
- You may opt to use `i8kmon`. However, this proved problematic for my case.
- BIOS fan control is restored automatically when `dell-bios-fan-control.service` stops (e.g. disabled, on shutdown).
