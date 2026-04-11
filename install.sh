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
    terminus-font powertop iw sof-firmware alsa-ucm-conf github-cli \
    qt5-wayland qt6-wayland inotify-tools \
    vulkan-intel lib32-vulkan-intel vulkan-tools \
    plasma-nm plasma-pa kscreen bluedevil kde-gtk-config breeze-gtk \
    plasma-systemmonitor wireless-regdb \
    openssh usbutils zsh zsh-completions ttf-meslo-nerd \
    jq tree unzip zip p7zip rsync tmux fzf ripgrep fd bat eza

if ! command -v yay &>/dev/null; then
    echo "=== Installing yay ==="
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

yay -S --needed --noconfirm google-chrome bibata-cursor-theme-bin \
    zsh-theme-powerlevel10k

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/power-profile-ac.sh" /usr/local/bin/power-profile-ac.sh
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/auto-brightness.py" /usr/local/bin/auto-brightness.py

echo "=== Installing hotkey handler ==="
if [[ ! -d "$USER_HOME/dev/hotkey-handler" ]]; then
    git clone --depth=1 https://github.com/dechros/hotkey-handler.git "$USER_HOME/dev/hotkey-handler"
fi
"$USER_HOME/dev/hotkey-handler/install.sh"

echo "=== Installing oh-my-zsh ==="
if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== Copying user config files ==="
mkdir -p "$USER_HOME/.config" "$USER_HOME/.local/share/icons" "$USER_HOME/.local/share/konsole"
cp -r "$REPO_DIR/user/.config/"* "$USER_HOME/.config/"
cp "$REPO_DIR/user/.local/share/icons/"* "$USER_HOME/.local/share/icons/"
cp "$REPO_DIR/user/.local/share/konsole/"* "$USER_HOME/.local/share/konsole/"

cp "$REPO_DIR/user/home/.zshrc" "$USER_HOME/.zshrc"
cp "$REPO_DIR/user/home/.p10k.zsh" "$USER_HOME/.p10k.zsh"
sudo chsh -s /usr/bin/zsh "$USERNAME"

echo "=== Setting up services ==="
sudo systemctl daemon-reload
sudo systemctl enable --now powertop
sudo systemctl enable --now auto-brightness.service
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply

echo "=== Configuring Wayland for Electron apps ==="
if ! grep -q '^ELECTRON_OZONE_PLATFORM_HINT' /etc/environment; then
    echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' | sudo tee -a /etc/environment
fi

echo "=== Setting locale ==="
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen

echo "=== Done. Reboot recommended. ==="
