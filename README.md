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
- Local LLM on the iGPU (see `scripts/75-ollama.sh`):
  - `ttm.conf` raises the iGPU's addressable RAM ceiling to ~26 GB so a large MoE model fits without spilling to the CPU; never lower the context length to fix spillover
  - One model resident at a time with a 30 minute keep-alive, flash attention and a q8_0 KV cache
  - `ollama-param-proxy` listens on 11435 and injects the tuned system prompt and sampling settings in front of ollama's `/v1`; opencode points at that port
  - `ollama-gpu-watch` detects spillover and recovers with `llm-fresh`
  - The kernel kills ollama before the desktop under memory pressure
- Lock screen unlock after resume: the i8042 keyboard port is rescanned so the internal keyboard types again, and the `kde` PAM service skips faillock so the greeter's premature authentication request on resume cannot lock the account
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
scripts/                install phases (firmware, packages, system, hotkey, user, env, display)
hotkey-handler/         source for the hotkey systemd service
appgrid/                patches for the AppGrid launcher (clean grid customization)
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
