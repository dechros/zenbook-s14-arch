#!/bin/bash
set -e
USER_HOME="$HOME"

echo "=== Applying KDE color scheme (Breeze Dark) ==="
plasma-apply-colorscheme BreezeDark || true

if [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo "=== Applying display settings (2880x1800@120, scale 1.75) ==="
    "$USER_HOME/.local/bin/zenbook-display.sh" || true
fi
