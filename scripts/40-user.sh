#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
USER_HOME="$HOME"
USERNAME="$(whoami)"

echo "=== Installing oh-my-zsh ==="
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== Copying user config files ==="
mkdir -p "$USER_HOME/.config" \
    "$USER_HOME/.local/share/icons" \
    "$USER_HOME/.local/share/konsole" \
    "$USER_HOME/.local/share/applications" \
    "$USER_HOME/.local/bin" \
    "$USER_HOME/Pictures/Wallpapers"
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
cp "$REPO_DIR/user/.local/share/icons/"* "$USER_HOME/.local/share/icons/"
cp "$REPO_DIR/user/.local/share/konsole/"* "$USER_HOME/.local/share/konsole/"
# No keyring: kwalletd and the kwallet Secret portal can never be D-Bus activated,
# the portal exposes no Secret interface, Chrome/Electron use the basic store.
mkdir -p "$USER_HOME/.local/share/dbus-1/services"
cp "$REPO_DIR/user/.local/share/dbus-1/services/"* "$USER_HOME/.local/share/dbus-1/services/"
# anydesk.desktop override: HiDPI scaling fix (GDK_SCALE=1, remote ekrani doldursun)
cp "$REPO_DIR/user/.local/share/applications/"* "$USER_HOME/.local/share/applications/"
echo "=== Scroll speed: Konsole fast, other apps slower ==="
# Pointer speed and scroll factors per device come from user/.config/kcminputrc.
# The G305 scroll factor must stay >= 1: below 1 Konsole reports a wheel event
# to TUI apps (Claude Code) only every second notch.
# Qt/KDE apps: 1 line per notch. Konsole reads its own value from
# ~/.config/konsole-scroll/kdeglobals via XDG_CONFIG_DIRS in its launchers.
kwriteconfig6 --file kdeglobals --group KDE --key WheelScrollLines 1
sed -E "s#^Exec=konsole#Exec=env XDG_CONFIG_DIRS=$USER_HOME/.config/konsole-scroll:$USER_HOME/.config:/etc/xdg konsole#" \
    /usr/share/applications/org.kde.konsole.desktop > "$USER_HOME/.local/share/applications/org.kde.konsole.desktop"
update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
mkdir -p "$USER_HOME/.local/share/easyeffects/output"
cp "$REPO_DIR/user/.local/share/easyeffects/output/"*.json "$USER_HOME/.local/share/easyeffects/output/"
install -m 755 "$REPO_DIR/user/.local/bin/"* "$USER_HOME/.local/bin/"
cp "$REPO_DIR/user/Pictures/Wallpapers/"* "$USER_HOME/Pictures/Wallpapers/"
cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"

echo "=== Enabling user services ==="
systemctl --user daemon-reload || true
# audio-autoswitch: route EasyEffects output (EQ) to the last-plugged device
systemctl --user enable audio-autoswitch.service || true

echo "=== Switching default shell to zsh ==="
sudo chsh -s /usr/bin/zsh "$USERNAME"
