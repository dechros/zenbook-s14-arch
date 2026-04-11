#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Installing hotkey handler ==="
sudo cp "$REPO_DIR/hotkey-handler.py" /usr/local/bin/hotkey-handler.py
sudo cp "$REPO_DIR/launch-claude.sh" /usr/local/bin/launch-claude.sh
sudo cp "$REPO_DIR/toggle-claude.sh" /usr/local/bin/toggle-claude.sh
sudo cp "$REPO_DIR/launch-emoji.sh" /usr/local/bin/launch-emoji.sh
sudo chmod +x /usr/local/bin/hotkey-handler.py
sudo chmod +x /usr/local/bin/launch-claude.sh
sudo chmod +x /usr/local/bin/toggle-claude.sh
sudo chmod +x /usr/local/bin/launch-emoji.sh

sudo cp "$REPO_DIR/hotkey-handler.service" /etc/systemd/system/
sudo cp "$REPO_DIR/hotkey-handler-resume.service" /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now hotkey-handler
sudo systemctl enable hotkey-handler-resume

echo "=== Done ==="
