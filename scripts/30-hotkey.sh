#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
SRC="$REPO_DIR/hotkey-handler"

echo "=== Installing hotkey handler ==="
sudo install -m 755 "$SRC/hotkey-handler.py" /usr/local/bin/hotkey-handler.py
sudo install -m 755 "$SRC/launch-claude.sh"  /usr/local/bin/launch-claude.sh
sudo install -m 755 "$SRC/toggle-claude.sh"  /usr/local/bin/toggle-claude.sh
sudo install -m 644 "$SRC/hotkey-handler.service"        /etc/systemd/system/
sudo install -m 644 "$SRC/hotkey-handler-resume.service" /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now hotkey-handler.service
sudo systemctl enable hotkey-handler-resume.service
