# hotkey-handler

Hotkey handler service for ASUS Zenbook S14 UX5406SA on Linux.

Handles hardware hotkeys via evdev and GPIO for mic mute LED, camera toggle, and Copilot key (F23) to launch Claude Code.

## Scripts

- `hotkey-handler.py` -- Main service. Listens to Asus WMI and keyboard events.
- `launch-claude.sh` -- Opens Claude Code in GNOME Console.
- `toggle-claude.sh` -- Minimizes/restores the Claude Code window via GNOME Shell DBus.

## Install

```bash
git clone https://github.com/dechros/hotkey-handler.git
cd hotkey-handler
./install.sh
```

## Dependencies

- python-evdev
- python-gpiod
