#!/usr/bin/env python3
import evdev
import gpiod
from gpiod.line import Direction, Value
import glob
import os
import select
import subprocess

MICMUTE_LED_SYSFS = '/sys/class/leds/platform::micmute/brightness'
MICMUTE_TRIGGER   = '/sys/class/leds/platform::micmute/trigger'
CAMERA_BIND       = '/sys/bus/usb/drivers/usb/bind'
CAMERA_UNBIND     = '/sys/bus/usb/drivers/usb/unbind'
CAMERA_USB        = '3-5'
CAMERA_STATE      = '/var/lib/hotkey-handler/camera_enabled'
GPIO_CHIP         = '/dev/gpiochip2'
GPIO_MLED         = 30
GPIO_CLED         = 31

def find_device(name):
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if dev.name == name:
            return dev
    raise RuntimeError(f'Input device not found: {name}')

def write_file(path, value):
    with open(path, 'w') as f:
        f.write(str(value))

def read_state():
    try:
        with open(CAMERA_STATE) as f:
            return f.read().strip() == '1'
    except:
        return True

def save_state(enabled):
    os.makedirs(os.path.dirname(CAMERA_STATE), exist_ok=True)
    with open(CAMERA_STATE, 'w') as f:
        f.write('1' if enabled else '0')

def user_logged_in():
    try:
        result = subprocess.run(
            ['loginctl', 'list-sessions', '--no-legend'],
            capture_output=True, text=True
        )
        for line in result.stdout.strip().split('\n'):
            parts = line.split()
            if len(parts) >= 3 and int(parts[1]) >= 1000 and os.path.exists(f'/run/user/{parts[1]}/bus'):
                return True
    except:
        pass
    return False

def find_wayland_display(uid):
    sockets = glob.glob(f'/run/user/{uid}/wayland-*')
    sockets = [os.path.basename(s) for s in sockets if not s.endswith('.lock')]
    return sockets[0] if sockets else 'wayland-0'

def run_as_user(cmd):
    try:
        result = subprocess.run(
            ['loginctl', 'list-sessions', '--no-legend'],
            capture_output=True, text=True
        )
        for line in result.stdout.strip().split('\n'):
            parts = line.split()
            if len(parts) >= 3:
                uid = parts[1]
                user = parts[2]
                if int(uid) < 1000 or not os.path.exists(f'/run/user/{uid}/bus'):
                    continue
                wayland_display = find_wayland_display(uid)
                env = {
                    'DBUS_SESSION_BUS_ADDRESS': f'unix:path=/run/user/{uid}/bus',
                    'WAYLAND_DISPLAY': wayland_display,
                    'XDG_SESSION_TYPE': 'wayland',
                    'QT_QPA_PLATFORM': 'wayland',
                    'QT_QPA_PLATFORMTHEME': 'kde',
                    'KDE_FULL_SESSION': 'true',
                    'KDE_SESSION_VERSION': '6',
                    'LANG': 'en_US.UTF-8',
                    'LANGUAGE': 'en_US:en',
                    'LC_ALL': 'en_US.UTF-8',
                    'PATH': f'/home/{user}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin',
                    'HOME': f'/home/{user}',
                    'USER': user,
                    'LOGNAME': user,
                    'XDG_RUNTIME_DIR': f'/run/user/{uid}',
                    'XDG_DATA_DIRS': f'/home/{user}/.local/share:/usr/local/share:/usr/share',
                    'XDG_CONFIG_HOME': f'/home/{user}/.config',
                    'XDG_CONFIG_DIRS': f'/home/{user}/.config:/etc/xdg',
                }
                subprocess.Popen(
                    ['runuser', '-u', user, '--'] + cmd,
                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
                break
    except:
        pass

def toggle_claude():
    if os.path.exists('/tmp/claude-ai-open'):
        run_as_user(['/usr/local/bin/toggle-claude.sh'])
    else:
        run_as_user(['/usr/local/bin/launch-claude.sh'])

def kde_osd(icon, text):
    run_as_user(['gdbus', 'call', '--session',
                 '--dest', 'org.kde.plasmashell',
                 '--object-path', '/org/kde/osdService',
                 '--method', 'org.kde.osdService.showText',
                 icon, text])

def main():
    write_file(MICMUTE_TRIGGER, 'none')

    mic_muted = False
    camera_enabled = read_state()

    mled = gpiod.request_lines(
        GPIO_CHIP,
        consumer='hotkey-handler',
        config={GPIO_MLED: gpiod.LineSettings(direction=Direction.OUTPUT)}
    )
    cled = gpiod.request_lines(
        GPIO_CHIP,
        consumer='hotkey-handler',
        config={GPIO_CLED: gpiod.LineSettings(direction=Direction.OUTPUT)}
    )

    mled.set_value(GPIO_MLED, Value.INACTIVE)
    cled.set_value(GPIO_CLED, Value.ACTIVE if camera_enabled else Value.INACTIVE)
    write_file(MICMUTE_LED_SYSFS, 0)

    dev_wmi = find_device('Asus WMI hotkeys')
    dev_kbd = find_device('AT Translated Set 2 keyboard')
    devices = {dev_wmi.fd: dev_wmi, dev_kbd.fd: dev_kbd}

    while True:
        r, _, _ = select.select(devices.keys(), [], [])
        for fd in r:
            for event in devices[fd].read():
                if event.type != evdev.ecodes.EV_KEY or event.value != 1:
                    continue

                if not user_logged_in():
                    continue

                if event.code == evdev.ecodes.KEY_MICMUTE:
                    mic_muted = not mic_muted
                    mled.set_value(GPIO_MLED, Value.ACTIVE if mic_muted else Value.INACTIVE)
                    write_file(MICMUTE_LED_SYSFS, 1 if mic_muted else 0)

                elif event.code == evdev.ecodes.KEY_CAMERA:
                    if camera_enabled:
                        write_file(CAMERA_UNBIND, CAMERA_USB)
                        camera_enabled = False
                        cled.set_value(GPIO_CLED, Value.INACTIVE)
                        kde_osd('camera-off', 'Camera Off')
                    else:
                        write_file(CAMERA_BIND, CAMERA_USB)
                        camera_enabled = True
                        cled.set_value(GPIO_CLED, Value.ACTIVE)
                        kde_osd('camera-on', 'Camera On')
                    save_state(camera_enabled)

                elif event.code == evdev.ecodes.KEY_F23:
                    toggle_claude()

if __name__ == '__main__':
    main()
