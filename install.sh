#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$HOME"
USERNAME="$(whoami)"

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user, not root."
    exit 1
fi

echo "=== Installing packages ==="
sudo pacman -S --needed --noconfirm \
    python-evdev python-gpiod papirus-icon-theme \
    terminus-font powertop iw sof-firmware alsa-ucm-conf github-cli

if ! command -v yay &>/dev/null; then
    echo "=== Installing yay ==="
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

yay -S --needed --noconfirm google-chrome papirus-folders-git \
    ttf-meslo-nerd-font-powerlevel10k zsh-theme-powerlevel10k

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
sudo cp -r "$REPO_DIR/system/usr/"* /usr/
sudo chmod +x /usr/local/bin/hotkey-handler.py
sudo chmod +x /usr/local/bin/launch-claude.sh
sudo chmod +x /usr/local/bin/toggle-claude.sh
sudo chmod +x /usr/local/bin/sync-greeter
sudo chmod 440 /etc/sudoers.d/sync-greeter
sudo chown root:root /etc/sudoers.d/sync-greeter

echo "=== Installing oh-my-zsh ==="
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== Copying user config files ==="
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
mkdir -p "$USER_HOME/.local/share/konsole"
cp "$REPO_DIR/user/.config/konsole/Claude AI.profile" "$USER_HOME/.local/share/konsole/"
cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"
chsh -s /usr/bin/zsh "$USERNAME"

echo "=== Setting up services ==="
sudo systemctl daemon-reload
sudo systemctl enable --now hotkey-handler
sudo systemctl enable --now powertop

echo "=== Setting up GRUB font ==="
sudo grub-mkfont -s 36 /usr/share/fonts/TTF/MesloLGS-NF-Regular.ttf \
    -o /boot/grub/fonts/MesloLGS36.pf2
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Setting up icons ==="
papirus-folders -C teal --theme Papirus-Dark

echo "=== Setting locale ==="
sudo locale-gen

echo "=== Done. Reboot recommended. ==="
