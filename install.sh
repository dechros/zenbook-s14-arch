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
sudo cp "$DRIVER_TMP/firmware/intel/ish/ish_lnlm_ef534c00_fb3b8d86.bin" \
    /lib/firmware/intel/ish/
rm -rf "$DRIVER_TMP"

echo "=== Installing packages ==="
sudo pacman -S --needed --noconfirm \
    python-evdev libgpiod papirus-icon-theme \
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

echo "=== Installing hotkey handler ==="
if [[ ! -d "$USER_HOME/dev/hotkey-handler" ]]; then
    git clone --depth=1 https://github.com/dechros/hotkey-handler.git "$USER_HOME/dev/hotkey-handler"
fi
"$USER_HOME/dev/hotkey-handler/install.sh"

echo "=== Installing GNOME extensions ==="
mkdir -p "$USER_HOME/.local/share/gnome-shell/extensions"

if [[ ! -d "$USER_HOME/dev/gnome-shell-helper" ]]; then
    git clone --depth=1 https://github.com/dechros/gnome-shell-helper.git "$USER_HOME/dev/gnome-shell-helper"
fi
ln -sf "$USER_HOME/dev/gnome-shell-helper" "$USER_HOME/.local/share/gnome-shell/extensions/camera-osd@dechros"

yay -S --needed --noconfirm gnome-shell-extension-dash-to-dock gnome-extensions-cli
sudo pacman -S --needed --noconfirm gnome-shell-extension-appindicator
gext install window-title-is-back@fthx

gsettings set org.gnome.shell disable-extension-version-validation true
gsettings set org.gnome.shell enabled-extensions "['dash-to-dock@micxgx.gmail.com', 'window-title-is-back@fthx', 'camera-osd@dechros', 'appindicatorsupport@rgcjonas.gmail.com']"

echo "=== Installing oh-my-zsh ==="
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== Copying user config files ==="
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
mkdir -p "$USER_HOME/.local/share/icons"
cp "$REPO_DIR/user/.local/share/icons/"* "$USER_HOME/.local/share/icons/"

cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"
sudo chsh -s /usr/bin/zsh "$USERNAME"

echo "=== Setting up services ==="
sudo systemctl daemon-reload
sudo systemctl enable --now powertop

echo "=== Configuring systemd-boot ==="
sudo mkdir -p /boot/loader
if [[ -f /boot/loader/loader.conf ]] && grep -q '^console-mode' /boot/loader/loader.conf; then
    sudo sed -i 's/^console-mode.*/console-mode max/' /boot/loader/loader.conf
elif [[ -f /boot/loader/loader.conf ]] && grep -q '^#console-mode' /boot/loader/loader.conf; then
    sudo sed -i 's/^#console-mode.*/console-mode max/' /boot/loader/loader.conf
else
    echo 'console-mode max' | sudo tee -a /boot/loader/loader.conf
fi

echo "=== Setting locale ==="
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen

echo "=== Done. Reboot recommended. ==="
