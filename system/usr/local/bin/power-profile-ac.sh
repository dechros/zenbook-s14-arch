#!/bin/bash
AC_ONLINE=$(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1)
if [[ "$AC_ONLINE" == "1" ]]; then
    powerprofilesctl set performance
else
    powerprofilesctl set balanced
fi
