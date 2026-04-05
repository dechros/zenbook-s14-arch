#!/bin/bash
SCREEN=/sys/class/backlight/intel_backlight
KBD=/sys/class/leds/asus::kbd_backlight

MAX_SCREEN=$(cat "$SCREEN/max_brightness")
MAX_KBD=$(cat "$KBD/max_brightness")
LAST=-1

while true; do
    SB=$(cat "$SCREEN/brightness")
    KBD_VAL=$(( ((MAX_SCREEN - SB) * MAX_KBD + MAX_SCREEN / 2) / MAX_SCREEN ))
    if [[ "$KBD_VAL" != "$LAST" ]]; then
        echo "$KBD_VAL" > "$KBD/brightness"
        LAST=$KBD_VAL
    fi
    sleep 1
done
