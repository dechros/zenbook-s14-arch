#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="$HOME"
USERNAME="$(whoami)"

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user, not root."
    exit 1
fi

echo "=== Installing base dependencies ==="
sudo pacman -S --needed --noconfirm git

echo "=== Installing Zenbook S14 drivers ==="
DRIVER_TMP=$(mktemp -d)
git clone --depth=1 https://github.com/dantmnf/zenbook-s14-linux.git "$DRIVER_TMP"
sudo mkdir -p /lib/firmware/intel/ish
sudo mkdir -p /lib/firmware/intel/sof-ipc4-tplg
sudo cp "$DRIVER_TMP/firmware/intel/ish/ish_lnlm_ef534c00_fb3b8d86.bin" \
    /lib/firmware/intel/ish/
sudo cp "$DRIVER_TMP/firmware/intel/sof-ipc4-tplg/sof-lnl-cs42l43-l0-cs35l56-l23-2ch.tplg" \
    /lib/firmware/intel/sof-ipc4-tplg/
rm -rf "$DRIVER_TMP"

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

yay -S --needed --noconfirm google-chrome \
    ttf-meslo-nerd-font-powerlevel10k zsh-theme-powerlevel10k

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
sudo cp -r "$REPO_DIR/system/usr/"* /usr/
sudo chmod +x /usr/local/bin/hotkey-handler.py
sudo chmod +x /usr/local/bin/launch-claude.sh
sudo chmod +x /usr/local/bin/toggle-claude.sh

echo "=== Installing oh-my-zsh ==="
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== Copying user config files ==="
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
mkdir -p "$USER_HOME/.local/share/icons"
cp "$REPO_DIR/user/.local/share/icons/"* "$USER_HOME/.local/share/icons/"

echo "=== Installing Camera OSD extension ==="
git clone --depth=1 https://github.com/dechros/camera-osd-gnome.git "$USER_HOME/dev/camera-osd-gnome"
mkdir -p "$USER_HOME/.local/share/gnome-shell/extensions"
ln -sf "$USER_HOME/dev/camera-osd-gnome" "$USER_HOME/.local/share/gnome-shell/extensions/camera-osd@dechros"

cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"
chsh -s /usr/bin/zsh "$USERNAME"

echo "=== Setting up services ==="
sudo systemctl daemon-reload
sudo systemctl enable --now hotkey-handler
sudo systemctl enable hotkey-handler-resume
sudo systemctl enable --now powertop

echo "=== Setting up GRUB font ==="
sudo grub-mkfont -s 36 /usr/share/fonts/TTF/MesloLGS-NF-Regular.ttf \
    -o /boot/grub/fonts/MesloLGS36.pf2
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Setting locale ==="
sudo locale-gen

echo "=== Done. Reboot recommended. ==="
