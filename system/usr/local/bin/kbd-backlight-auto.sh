#!/bin/bash
SCREEN=/sys/class/backlight/intel_backlight
KBD=/sys/class/leds/asus::kbd_backlight

MAX_SCREEN=$(cat "$SCREEN/max_brightness")
MAX_KBD=$(cat "$KBD/max_brightness")

last_screen=-1
last_kbd=-1

while true; do
    cur_screen=$(cat "$SCREEN/brightness")
    cur_kbd=$(cat "$KBD/brightness")

    if [[ "$cur_screen" != "$last_screen" ]]; then
        target=$(( ((MAX_SCREEN - cur_screen) * MAX_KBD + MAX_SCREEN / 2) / MAX_SCREEN ))
        if [[ "$target" != "$cur_kbd" ]]; then
            echo "$target" > "$KBD/brightness"
            last_kbd=$target
        else
            last_kbd=$cur_kbd
        fi
        last_screen=$cur_screen
    elif [[ "$cur_kbd" != "$last_kbd" ]]; then
        last_kbd=$cur_kbd
    fi

    sleep 1
done
