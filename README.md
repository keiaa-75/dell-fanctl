# dell-fanctl

A minimal, reliable fan control setup for Dell laptops on Linux, bypassing the broken BIOS fan control that keeps fans silent until relatively high temperatures.

Tested on: Dell Latitude 5300. Likely works on other Dell laptops that use the `dell-smm-hwmon` (i8k) kernel module.

## The Problem

On many Dell laptops, the BIOS fan control is overly conservative. It keeps fans completely off until the CPU reaches 70°C or higher.

This project takes a simpler approach: disable BIOS fan control at boot, then run a plain bash loop that reads CPU temperature and sets fan speed accordingly via `i8kfan`.

## Stack

- `dell-smm-hwmon` — kernel module that exposes the Dell SMM interface to userspace
- [`dell-bios-fan-control`](https://github.com/TomFreudenberg/dell-bios-fan-control) — disables BIOS fan control at boot so the OS can take over
- `i8kfan` (from `i8kutils`) — the actual command our script uses to set fan speeds
- `fan-control.sh` — our loop that reads temperatures and decides what speed to set automatically

## Installation

1. Install dependencies:
```bash
sudo apt install i8kutils make git
```

2. Build and install:
```bash
make
sudo make install
```

You may run `make help` for details on available targets and configurable variables.

3. Optionally, edit the config file to customize behavior:
```bash
sudo nano /usr/local/etc/dell-fanctl.conf
```

4. Enable and start the services:
```bash
sudo make enable
```

## Configuration

To customize behavior, edit `/usr/local/etc/dell-fanctl.conf`. The script falls back to built-in defaults if the file is absent, so this is optional.

```bash
TEMP_LOW=20     # fan runs at low speed above this (°C)
TEMP_HIGH=75    # fan runs at max above this (°C)
HYST_OFFSET=10  # how far temp must drop before stepping down
POLL_INTERVAL=5 # how often to check temperature (seconds)
```

Fan speed steps down with hysteresis: it won't drop from max to low until the temperature falls `HYST_OFFSET` degrees below `TEMP_HIGH`, and won't turn off entirely until it falls `HYST_OFFSET` degrees below `TEMP_LOW`.

## Notes

- If `i8kfan` returns `-1` for the left fan, your laptop likely only has one physical fan. This is normal.
- If you use `i8kmon`, disable it. It will conflict with `fan-control.sh`.
- You may opt to use `i8kmon`. However, this proved problematic for my case.
- BIOS fan control is restored automatically when `dell-bios-fan-control.service` stops (e.g. disabled, on shutdown).
