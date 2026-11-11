#!/bin/bash
set -e

# Kernel cmdline cleanup for Lunar Lake (Intel Xe).
# xe.enable_psr=0 was a workaround for a black-screen hard freeze under GPU
# load (CS2). On kernel 7.3.x the freeze is fixed (framebuffers are no longer
# allocated in stolen memory) and PSR is left at the driver default to save
# power on the OLED panel. intel_idle.max_cstate=8 never limited anything on
# Lunar Lake (ACPI _CST exposes only POLL/C1/C2/C3). Both are stripped from
# existing installs.

echo "=== Cleaning stale Lunar Lake kernel parameters ==="
CMDLINE=$(cat /etc/kernel/cmdline)
NEW=$(echo "$CMDLINE" | sed -E 's/ ?intel_idle\.max_cstate=[0-9]+//; s/ ?xe\.enable_psr=[0-9]+//')
if [[ "$NEW" == "$CMDLINE" ]]; then
    echo "kernel cmdline already up to date"
else
    echo "$NEW" | sudo tee /etc/kernel/cmdline >/dev/null
    sudo mkinitcpio -p linux-cachyos
fi

# iGPU access for user-space compute and video (render/video groups).
sudo usermod -aG render,video "$USER"
