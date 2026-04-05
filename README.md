# zenbook-s14-arch

Post-install configuration for ASUS Zenbook S14 UX5406SA running Arch Linux with GNOME.

## Hardware

- CPU: Intel Core Ultra 7 258V (Lunar Lake)
- GPU: Intel Arc Graphics 140V
- Display: 2880x1800 OLED, 120Hz
- Audio: CS35L56 / CS42L43 / DMIC on SoundWire
- WiFi/BT: Intel BE201

## What this does

- Hotkey handler service: mic mute LED, camera toggle, Copilot key (F23) launches Claude Code
- Hotkey resume service: restores GPIO LED state after suspend/wake
- System locale: English UI, Turkish date/time/currency formats, Turkish keyboard
- systemd-boot: `console-mode max` for HiDPI display
- Console font: Terminus 32px
- Power: powertop auto-tune, WiFi power save disabled
- Browser: Google Chrome
- Icons: Papirus, custom white Arch Linux SVG icons
- Shell: ZSH + oh-my-zsh + Powerlevel10k

## Drivers

Installs firmware files from [dantmnf/zenbook-s14-linux](https://github.com/dantmnf/zenbook-s14-linux) for:

- ISH firmware (`ish_lnlm_ef534c00_fb3b8d86.bin`) -- required for sensor hub

## Install

```bash
git clone https://github.com/dechros/zenbook-s14-arch.git
cd zenbook-s14-arch
./install.sh
```
