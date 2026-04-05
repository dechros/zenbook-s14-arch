#!/bin/bash
ALS=/sys/bus/iio/devices/iio:device2/in_illuminance_raw

last_target=-1
while true; do
    lux=$(cat "$ALS" 2>/dev/null)
    [[ -z "$lux" ]] && sleep 5 && continue

    # raw sensor * 0.001 = lux. log10-based mapping: 2lx->0.10, 100lx->0.67, 1000lx->1.00
    target=$(awk -v l="$lux" 'BEGIN{
        if (l < 2) l = 2;
        t = log(l)/log(10) / 3.0 - 1.0;
        if (t < 0.10) t = 0.10;
        if (t > 1.00) t = 1.00;
        printf "%.2f", t;
    }')

    if [[ "$target" != "$last_target" ]]; then
        gdbus call --session --dest org.gnome.Shell \
            --object-path /org/gnome/Shell/Brightness \
            --method org.gnome.Shell.Brightness.SetAutoBrightnessTarget \
            "$target" >/dev/null 2>&1
        last_target=$target
    fi
    sleep 3
done
