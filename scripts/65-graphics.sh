#!/bin/bash
set -e

# Drop old Lunar Lake workarounds: the PSR freeze is fixed in kernel 7.3 and
# max_cstate=8 never limited anything.

echo "=== Cleaning stale Lunar Lake kernel parameters ==="
CMDLINE=$(cat /etc/kernel/cmdline)
NEW=$(echo "$CMDLINE" | sed -E 's/ ?intel_idle\.max_cstate=[0-9]+//; s/ ?xe\.enable_psr=[0-9]+//')
if [[ "$NEW" == "$CMDLINE" ]]; then
    echo "kernel cmdline already up to date"
else
    echo "$NEW" | sudo tee /etc/kernel/cmdline >/dev/null
    sudo mkinitcpio -p linux-cachyos
fi

sudo usermod -aG render,video "$USER"
