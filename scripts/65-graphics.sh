#!/bin/bash
set -e

# Lunar Lake (Intel Xe) hard-freeze mitigation.
# Symptom: black screen + full system hard-freeze under GPU load (e.g. CS2),
# no panic logged (system locks before it can write). Display log shows
# "Selective fetch area calculation failed in pipe A" (PSR2 selective fetch).
# Fix: disable Panel Self Refresh on the xe driver via kernel cmdline.
# Reversible: remove the param and rebuild the UKI.
#
# Status (2026-11, kernel 7.3.3): the selective fetch message is a one-time
# fallback notice, not a fault, and other Lunar Lake reports tie this freeze
# class to framebuffers allocated in stolen memory, fixed upstream in 7.2/7.3.
# PSR stays off until CS2 has been played on 7.3.x without a freeze; then
# try xe.enable_psr=1 (PSR1 only) before removing the parameter.
#
# intel_idle.max_cstate=8 is removed if present: Lunar Lake exposes only
# POLL/C1/C2/C3 through ACPI _CST, so the limit never cut anything.

echo "=== Disabling PSR on Intel Xe (Lunar Lake freeze mitigation) ==="
CMDLINE=$(cat /etc/kernel/cmdline)
NEW=$(echo "$CMDLINE" | sed -E 's/ ?intel_idle\.max_cstate=[0-9]+//')
[[ "$NEW" == *"xe.enable_psr=0"* ]] || NEW="$NEW xe.enable_psr=0"
if [[ "$NEW" == "$CMDLINE" ]]; then
    echo "kernel cmdline already up to date"
else
    echo "$NEW" | sudo tee /etc/kernel/cmdline >/dev/null
    sudo mkinitcpio -p linux-cachyos
fi

# iGPU access for user-space compute and video (render/video groups).
sudo usermod -aG render,video "$USER"
