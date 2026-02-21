#!/bin/bash

TEMP_LOW=20
TEMP_MED=55
TEMP_HIGH=75

while true; do
    TEMP=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -n | tail -1)
    TEMP=$((TEMP / 1000))

    if [ "$TEMP" -ge "$TEMP_HIGH" ]; then
        /usr/bin/i8kfan 0 2
    elif [ "$TEMP" -ge "$TEMP_MED" ]; then
        /usr/bin/i8kfan 0 2
    elif [ "$TEMP" -ge "$TEMP_LOW" ]; then
        /usr/bin/i8kfan 0 1
    else
        /usr/bin/i8kfan 0 0
    fi

    sleep 5
done
