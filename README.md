# zenbookS14Arch

Post-install configuration for ASUS Zenbook S14 UX5406SA running Arch Linux with KDE Plasma 6.

## Hardware

- CPU: Intel Core Ultra 7 258V (Lunar Lake)
- GPU: Intel Arc Graphics 140V
- Display: 2880x1800 OLED, 120Hz
- Audio: CS35L56 / CS42L43 / DMIC on SoundWire
- WiFi/BT: Intel BE201

## What this does

- Hotkey handler service: mic mute LED, camera toggle, Copilot key (F23) launches Claude Code in Konsole
- SDDM greeter: wallpaper, cursor, scaling sync via `sync-greeter` command
- System locale: English UI, Turkish date/time/currency formats, Turkish keyboard
- GRUB: MesloLGS NF font at 36px for HiDPI display
- Console font: Terminus 32px
- Power: powertop auto-tune, WiFi power save disabled
- Browser: Google Chrome
- Icons: Breeze Dark
- Shell: ZSH + oh-my-zsh + Powerlevel10k

## Install

```bash
git clone https://github.com/dechros/zenbookS14Arch.git
cd zenbookS14Arch
./install.sh
```

## After install

Run `sync-greeter` to copy your current wallpaper and cursor settings to the SDDM greeter.
