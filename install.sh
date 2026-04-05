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
    python-evdev libgpiod papirus-icon-theme gnome-backgrounds gnome-characters \
    terminus-font powertop iw sof-firmware alsa-ucm-conf github-cli \
    qt5-wayland qt6-wayland inotify-tools \
    vulkan-intel lib32-vulkan-intel vulkan-tools

if ! command -v yay &>/dev/null; then
    echo "=== Installing yay ==="
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

yay -S --needed --noconfirm google-chrome bibata-cursor-theme-bin \
    ttf-meslo-nerd-font-powerlevel10k zsh-theme-powerlevel10k

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
sudo chmod 440 /etc/sudoers.d/gdm-wallpaper-sync
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/kbd-backlight-auto.sh" /usr/local/bin/kbd-backlight-auto.sh
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/power-profile-ac.sh" /usr/local/bin/power-profile-ac.sh
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/gdm-wallpaper-update" /usr/local/bin/gdm-wallpaper-update
sudo install -m 755 "$REPO_DIR/system/usr/local/bin/gdm-wallpaper-sync.sh" /usr/local/bin/gdm-wallpaper-sync.sh
sudo install -d -m 755 /etc/dconf/profile
sudo install -m 644 "$REPO_DIR/system/etc/dconf/profile/gdm" /etc/dconf/profile/gdm

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

echo "=== Setting GNOME appearance ==="
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface cursor-size 24
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-seconds false
gsettings set org.gnome.desktop.interface clock-show-weekday false
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-l.svg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-d.svg'
gsettings set org.gnome.desktop.background picture-options 'zoom'

echo "=== Setting input devices ==="
gsettings set org.gnome.desktop.peripherals.mouse speed 0.28205128205128216
gsettings set org.gnome.desktop.peripherals.mouse natural-scroll false
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true

echo "=== Setting power ==="
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900
gsettings set org.gnome.desktop.session idle-delay 300

echo "=== Setting custom keyboard shortcuts ==="
EMOJI_PATH="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emoji-picker/"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/emoji-picker/']"
gsettings set "$EMOJI_PATH" name 'Emoji Picker'
gsettings set "$EMOJI_PATH" command 'gnome-characters'
gsettings set "$EMOJI_PATH" binding '<Super>ccedilla'

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
sudo systemctl enable --now kbd-backlight-auto.service
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=power_supply
systemctl --user daemon-reload
systemctl --user enable --now gdm-wallpaper-sync.service

echo "=== Configuring Wayland for Electron apps ==="
if ! grep -q '^ELECTRON_OZONE_PLATFORM_HINT' /etc/environment; then
    echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' | sudo tee -a /etc/environment
fi

echo "=== Configuring systemd-boot ==="
sudo mkdir -p /boot/loader
if [[ -f /boot/loader/loader.conf ]] && grep -q '^console-mode' /boot/loader/loader.conf; then
    sudo sed -i 's/^console-mode.*/console-mode max/' /boot/loader/loader.conf
elif [[ -f /boot/loader/loader.conf ]] && grep -q '^#console-mode' /boot/loader/loader.conf; then
    sudo sed -i 's/^#console-mode.*/console-mode max/' /boot/loader/loader.conf
else
    echo 'console-mode max' | sudo tee -a /boot/loader/loader.conf
fi
if grep -q '^timeout' /boot/loader/loader.conf; then
    sudo sed -i 's/^timeout.*/timeout 0/' /boot/loader/loader.conf
else
    echo 'timeout 0' | sudo tee -a /boot/loader/loader.conf
fi

echo "=== Silencing boot/shutdown output ==="
QUIET_FLAGS="quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 systemd.show_status=false"
if [[ -f /etc/kernel/cmdline ]] && ! grep -q 'quiet' /etc/kernel/cmdline; then
    sudo cp /etc/kernel/cmdline /etc/kernel/cmdline.bak
    CURRENT=$(cat /etc/kernel/cmdline)
    echo "$CURRENT $QUIET_FLAGS" | sudo tee /etc/kernel/cmdline
    sudo mkinitcpio -P
fi

echo "=== Setting locale ==="
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen

echo "=== Done. Reboot recommended. ==="
