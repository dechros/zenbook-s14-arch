# hotkey-handler

Hotkey handler service for ASUS Zenbook S14 UX5406SA on Linux.

Handles hardware hotkeys via evdev and GPIO for mic mute LED, camera toggle, and Copilot key (F23) to launch ai-assistant Code.

## Scripts

- `hotkey-handler.py` -- Main service. Listens to Asus WMI and keyboard events.
- `launch-ai-assistant.sh` -- Opens ai-assistant Code in GNOME Console.
- `toggle-ai-assistant.sh` -- Minimizes/restores the ai-assistant Code window via GNOME Shell DBus.

## Install

```bash
git clone https://github.com/dechros/hotkey-handler.git
cd hotkey-handler
./install.sh
```

## Dependencies

- python-evdev
- python-gpiod
