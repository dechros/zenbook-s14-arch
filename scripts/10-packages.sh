#!/bin/bash
set -e
echo "=== Installing packages (pacman) ==="
sudo pacman -S --needed --noconfirm git \
    python-evdev libgpiod papirus-icon-theme \
    terminus-font powertop iw sof-firmware alsa-ucm-conf github-cli \
    qt5-wayland qt6-wayland inotify-tools \
    vulkan-intel lib32-vulkan-intel vulkan-tools \
    plasma-nm plasma-pa kscreen bluedevil kde-gtk-config breeze-gtk \
    plasma-systemmonitor spectacle wireless-regdb \
    openssh usbutils zsh zsh-completions ttf-meslo-nerd \
    jq tree unzip zip p7zip rsync tmux fzf ripgrep fd bat eza

if ! command -v yay &>/dev/null; then
    echo "=== Installing yay ==="
    TMP=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMP/yay"
    (cd "$TMP/yay" && makepkg -si --noconfirm)
    rm -rf "$TMP"
fi

echo "=== Installing packages (AUR via yay) ==="
yay -S --needed --noconfirm google-chrome bibata-cursor-theme-bin \
    zsh-theme-powerlevel10k plasma6-applets-window-title
