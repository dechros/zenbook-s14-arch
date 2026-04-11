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
    "$USER_HOME/.local/bin" \
    "$USER_HOME/Pictures/Wallpapers"
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
cp "$REPO_DIR/user/.local/share/icons/"* "$USER_HOME/.local/share/icons/"
cp "$REPO_DIR/user/.local/share/konsole/"* "$USER_HOME/.local/share/konsole/"
install -m 755 "$REPO_DIR/user/.local/bin/"* "$USER_HOME/.local/bin/"
cp "$REPO_DIR/user/Pictures/Wallpapers/"* "$USER_HOME/Pictures/Wallpapers/"
cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"

echo "=== Installing arch-power-switch plasmoid ==="
TMP=$(mktemp -d)
git clone --depth=1 https://github.com/dechros/arch-power-switch.git "$TMP/aps"
kpackagetool6 -t Plasma/Applet -i "$TMP/aps/package" 2>/dev/null || \
    kpackagetool6 -t Plasma/Applet -u "$TMP/aps/package"
rm -rf "$TMP"

echo "=== Switching default shell to zsh ==="
sudo chsh -s /usr/bin/zsh "$USERNAME"
