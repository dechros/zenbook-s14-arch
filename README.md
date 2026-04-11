# zenbook-s14-arch

Post-install configuration for ASUS Zenbook S14 (UX5406SA) on Arch Linux with KDE Plasma Wayland.

## Hardware

- CPU: Intel Core Ultra 7 258V (Lunar Lake)
- GPU: Intel Arc Graphics 140V (xe driver)
- Display: 2880x1800 OLED 120Hz
- Audio: CS35L56 / CS42L43 / DMIC via SoundWire
- WiFi/BT: Intel BE201 Wi-Fi 7
- NPU: Intel VPU

## What it configures

- ISH firmware from [dantmnf/zenbook-s14-linux](https://github.com/dantmnf/zenbook-s14-linux) for sensor hub and Fn keys
- `wireless-regdb` so Wi-Fi 7 6 GHz band is usable
- KDE Plasma tray, display, Bluetooth, GTK theme and Window Title applet
- Konsole profile with MesloLGS Nerd Font 10pt and a dark colorscheme
- Zsh, oh-my-zsh and Powerlevel10k; PATH includes language toolchain bins
- Chrome flags for Wayland and `--password-store=basic` (KWallet disabled)
- Electron Wayland hint and system default shell via `/etc/environment`
- Locale: English UI with Turkish date, time and currency formats
- Auto keyboard backlight that inversely tracks screen brightness
- powertop auto-tune, USB HID autosuspend disabled
- KDE BreezeDark color scheme, 2880x1800 @120 Hz with 175% scale
- Hotkey handler service (see `hotkey-handler/`):
  - Camera key toggles USB bind with GPIO LED and an OSD
  - Copilot key (F23) launches, focuses, minimizes or restores Claude Code in Konsole
  - Fn+F7 opens the KScreen display configuration OSD and auto-hides after 3 seconds
  - Fn+F8 opens the Plasma emoji selector
  - Meta+F opens KRunner
  - Meta+P, Meta+. and Meta+F are consumed so they do not leak to focused apps

## Layout

```
install.sh              main entry, runs scripts/* in order
packages.txt            reference package list
scripts/                install phases (firmware, packages, system, hotkey, user, env, display)
hotkey-handler/         source for the hotkey systemd service
system/                 files copied to /
user/                   files copied to $HOME
```

## Install

```bash
git clone https://github.com/dechros/zenbook-s14-arch.git
cd zenbook-s14-arch
./install.sh
```

Reboot when finished.
