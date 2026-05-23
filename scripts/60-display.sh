#!/bin/bash
set -e
USER_HOME="$HOME"

echo "=== Applying KDE color scheme (Breeze Dark) ==="
plasma-apply-colorscheme BreezeDark || true

echo "=== Setting 24h clock for user and plasmalogin greeter ==="
mkdir -p "$HOME/.config"
if [[ -f "$HOME/.config/plasma-localerc" ]]; then
    sed -i 's/^LC_TIME=.*/LC_TIME=en_GB.UTF-8/' "$HOME/.config/plasma-localerc"
else
    printf '[Formats]\nLANG=en_US.UTF-8\nLC_TIME=en_GB.UTF-8\n' > "$HOME/.config/plasma-localerc"
fi

sudo mkdir -p /var/lib/plasmalogin/.config
sudo tee /var/lib/plasmalogin/.config/plasma-localerc > /dev/null <<'EOF'
[Formats]
LANG=en_US.UTF-8
LC_TIME=en_GB.UTF-8
EOF
sudo chown -R plasmalogin:plasmalogin /var/lib/plasmalogin/.config

if [[ -n "$WAYLAND_DISPLAY" ]]; then
    echo "=== Applying display settings (2880x1800@120, scale 1.75) ==="
    "$USER_HOME/.local/bin/zenbook-display.sh" || true
fi
