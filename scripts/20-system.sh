#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/auto-brightness.py" \
    /usr/local/bin/auto-brightness.py

if [[ -d "$REPO_DIR/system/boot" && -d /boot/loader ]]; then
    sudo cp -r "$REPO_DIR/system/boot/"* /boot/
fi

echo "=== Enabling system services ==="
sudo systemctl daemon-reload
sudo systemctl enable --now powertop.service
sudo systemctl enable --now auto-brightness.service
sudo udevadm control --reload-rules
sudo udevadm trigger
