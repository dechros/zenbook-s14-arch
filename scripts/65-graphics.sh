#!/bin/bash
set -e

# Lunar Lake (Intel Xe) hard-freeze mitigation.
# Symptom: black screen + full system hard-freeze under GPU load (e.g. CS2),
# no panic logged (system locks before it can write). Display log shows
# "Selective fetch area calculation failed in pipe A" (PSR2 selective fetch).
# Fix: disable Panel Self Refresh on the xe driver via kernel cmdline.
# Reversible: remove the param and rebuild the UKI.

echo "=== Disabling PSR on Intel Xe (Lunar Lake freeze mitigation) ==="
CMDLINE=$(cat /etc/kernel/cmdline)
if [[ "$CMDLINE" == *"xe.enable_psr=0"* ]]; then
    echo "xe.enable_psr=0 already set"
else
    echo "$CMDLINE xe.enable_psr=0" | sudo tee /etc/kernel/cmdline >/dev/null
    sudo mkinitcpio -p linux-cachyos
fi
