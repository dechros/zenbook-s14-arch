#!/bin/bash
set -e

SWAP_DEV=$(swapon --show=NAME --noheadings | head -1)
if [[ -z "$SWAP_DEV" ]]; then
    echo "=== No swap device found, skipping hibernate setup ==="
    exit 0
fi

SWAP_UUID=$(sudo blkid -s UUID -o value "$SWAP_DEV")
if [[ -z "$SWAP_UUID" ]]; then
    echo "=== Could not read swap UUID, skipping hibernate setup ==="
    exit 0
fi

echo "=== Enabling suspend-then-hibernate (swap: $SWAP_DEV, UUID: $SWAP_UUID) ==="

CMDLINE=$(cat /etc/kernel/cmdline)
if [[ "$CMDLINE" == *"resume=UUID=$SWAP_UUID"* ]]; then
    echo "resume= already set"
else
    CMDLINE=$(echo "$CMDLINE" | sed -E 's/ ?resume=[^ ]*//g')
    echo "$CMDLINE resume=UUID=$SWAP_UUID" | sudo tee /etc/kernel/cmdline
fi

if ! grep -q "^HOOKS=.*\bresume\b" /etc/mkinitcpio.conf; then
    sudo sed -i -E 's/^(HOOKS=\([^)]*\bblock\b)( [^)]*\bfilesystems\b)/\1 resume\2/' /etc/mkinitcpio.conf
fi

if grep -q "^#HibernateDelaySec=" /etc/systemd/sleep.conf; then
    sudo sed -i 's/^#HibernateDelaySec=.*/HibernateDelaySec=30min/' /etc/systemd/sleep.conf
elif ! grep -q "^HibernateDelaySec=" /etc/systemd/sleep.conf; then
    echo 'HibernateDelaySec=30min' | sudo tee -a /etc/systemd/sleep.conf
fi

if grep -q "^#SleepOperation=" /etc/systemd/logind.conf; then
    sudo sed -i 's/^#SleepOperation=.*/SleepOperation=suspend-then-hibernate suspend/' /etc/systemd/logind.conf
elif ! grep -q "^SleepOperation=" /etc/systemd/logind.conf; then
    echo 'SleepOperation=suspend-then-hibernate suspend' | sudo tee -a /etc/systemd/logind.conf
fi

sudo mkinitcpio -P
