#!/bin/bash
set -e

echo "=== Enabling multilib repository ==="
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include.*mirrorlist/ { /^#\[multilib\]/ s/^#//; /^#Include.*mirrorlist/ s/^#//; }' /etc/pacman.conf
    sudo pacman -Sy
fi

echo "=== Installing packages (pacman) ==="
sudo pacman -S --needed --noconfirm git \
    python-evdev libgpiod \
    terminus-font powertop iw sof-firmware alsa-ucm-conf \
    qt5-wayland qt6-wayland inotify-tools \
    vulkan-intel lib32-vulkan-intel vulkan-tools \
    intel-media-driver libva-intel-driver \
    plasma-nm plasma-pa kscreen bluedevil kde-gtk-config breeze-gtk \
    plasma-systemmonitor spectacle papirus-icon-theme \
    wireless-regdb \
    networkmanager network-manager-applet wpa_supplicant \
    cups cups-pk-helper system-config-printer \
    bluez bluez-utils \
    pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber gst-plugin-pipewire \
    power-profiles-daemon \
    openssh usbutils zsh zsh-completions ttf-meslo-nerd \
    zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
    firefox github-cli gwenview haruna \
    jq tree unzip zip 7zip rsync tmux fzf ripgrep fd bat eza wget \
    htop nano vim neovim \
    man-db man-pages xdg-utils \
    pacman-contrib reflector smartmontools ufw \
    steam

if ! command -v yay &>/dev/null; then
    echo "=== Installing yay ==="
    TMP=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMP/yay"
    (cd "$TMP/yay" && makepkg -si --noconfirm)
    rm -rf "$TMP"
fi

echo "=== Installing packages (AUR via yay) ==="
yay -S --needed --noconfirm \
    google-chrome \
    visual-studio-code-bin \
    octopi \
    bibata-cursor-theme-bin \
    bibata-cursor-gruvbox-git \
    gruvbox-plus-icon-theme-git \
    gruvbox-material-icon-theme-git \
    gruvbox-wallpaper \
    zsh-theme-powerlevel10k \
    plasma6-applets-window-title \
    plasma6-applets-separator-git \
    plasma6-applets-panel-spacer-extended \
    plasma6-applets-appgrid \
    plasma6-applets-resources-monitor \
    plasma6-applets-system-panel \
    plasma6-applets-weather-widget-3-git
