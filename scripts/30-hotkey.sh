#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
SRC="$REPO_DIR/hotkey-handler"

echo "=== Installing hotkey handler ==="
sudo install -m 755 "$SRC/hotkey-handler.py" /usr/local/bin/hotkey-handler.py
# AI terminal launcher/toggle scripts are kept privately outside the repo.
AI_SRC="$HOME/.local/share/ai-terminal"
for f in launch-ai-terminal.sh toggle-ai-terminal.sh; do
    if [ -f "$AI_SRC/$f" ]; then
        sudo install -m 755 "$AI_SRC/$f" "/usr/local/bin/$f"
    fi
done
sudo install -m 644 "$SRC/hotkey-handler.service"        /etc/systemd/system/
sudo install -m 644 "$SRC/hotkey-handler-resume.service" /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now hotkey-handler.service
sudo systemctl enable hotkey-handler-resume.service
