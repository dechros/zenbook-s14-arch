#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
if [[ -d "$REPO_DIR/system/usr" ]]; then
    sudo cp -r "$REPO_DIR/system/usr/"* /usr/
fi
if [[ -d "$REPO_DIR/system/boot" && -d /boot/loader ]]; then
    sudo cp -r "$REPO_DIR/system/boot/"* /boot/
fi

echo "=== Building CachyOS UKI ==="
sudo mkinitcpio -p linux-cachyos

echo "=== Enabling system services ==="
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger
# anydesk: always-on backend so the relay stays connected; the system-sleep
# hook (30-anydesk-reconnect) restarts it on resume to recover the relay.
sudo systemctl enable anydesk.service || true
