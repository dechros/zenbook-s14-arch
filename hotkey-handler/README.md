# hotkey-handler

Keyboard and hardware key service for ASUS Zenbook S14 on KDE Plasma Wayland. Runs as a systemd root service, grabs the AT Translated Set 2 keyboard to intercept selected hotkeys, and forwards all other keys through a uinput virtual keyboard so normal typing is unaffected.

## Hotkeys

- Camera key: toggle USB camera bind with GPIO LED and a Plasma OSD
- Copilot key (F23): launch Konsole with `claude --dangerously-skip-permissions`, then focus, minimize or restore on repeat
- Fn+F7 (Meta+P): open KScreen display configuration OSD with 3 second auto-hide
- Fn+F8 (Meta+.): open Plasma emoji selector

Meta+P and Meta+. are consumed, so they never leak to focused applications.

## Files

- `hotkey-handler.py` main event loop
- `launch-claude.sh` spawns Konsole with Claude Code
- `toggle-claude.sh` focus/minimize/restore via KWin scripting
- `hotkey-handler.service` and `hotkey-handler-resume.service` unit files
- `install.sh` copies binaries to `/usr/local/bin` and enables the services

## Install

```bash
./install.sh
```

## Dependencies

- python-evdev
- libgpiod
- qt6-tools (`qdbus6`)
