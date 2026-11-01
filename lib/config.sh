#!/usr/bin/env bash
# Settings for dell-fanctl: defaults, validation, and loading.
# Requires parse-config.sh to be sourced first.

CONFIG_KEYS=(TEMP_LOW TEMP_HIGH HYST_OFFSET POLL_INTERVAL)

# upper limits; higher values would let the CPU run hotter
# or let it heat up for longer before the fans react
MAX_TEMP_HIGH=85
MAX_POLL_INTERVAL=10

set_defaults() {
	TEMP_LOW=20
	TEMP_HIGH=55
	HYST_OFFSET=10
	POLL_INTERVAL=5
}

validate_config() {
    local ok=1

    if [[ "$TEMP_LOW" -ge "$TEMP_HIGH" ]]; then
        echo "ERROR: TEMP_LOW ($TEMP_LOW) must be less than TEMP_HIGH ($TEMP_HIGH)."
        ok=0
    fi

    if [[ "$TEMP_HIGH" -gt "$MAX_TEMP_HIGH" ]]; then
    	echo "ERROR: TEMP_HIGH must be at most ${MAX_TEMP_HIGH}°C (got: $TEMP_HIGH)."
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

    if [[ "$POLL_INTERVAL" -gt "$MAX_POLL_INTERVAL" ]]; then
  		echo "ERROR: POLL_INTERVAL must be at most ${MAX_POLL_INTERVAL}s (got: $POLL_INTERVAL)."
     	ok=0
 	fi
 	
    [[ "$ok" -eq 1 ]]
}

# Sets the settings from the config file,
# or the defaults if the file is missing or invalid.
load_config() {
	local file=$1

	set_defaults

	if [[ -f "$file" ]]; then
		parse_config "$file" "${CONFIG_KEYS[@]}"
	fi

	if ! validate_config; then
		echo "WARNING: Invalid config; using defaults."
		set_defaults
	fi
}