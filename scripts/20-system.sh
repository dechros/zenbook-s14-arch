#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
if [[ -d "$REPO_DIR/system/boot" && -d /boot/loader ]]; then
    sudo cp -r "$REPO_DIR/system/boot/"* /boot/
fi

echo "=== Building CachyOS UKI ==="
sudo mkinitcpio -p linux-cachyos

echo "=== Enabling system services ==="
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger
