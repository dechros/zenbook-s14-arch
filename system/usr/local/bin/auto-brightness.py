#!/usr/bin/env python3
import math
import os
import subprocess
import time

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
SCREEN_MIN = 4
SCREEN_MAX = 400
KBD_MAX = 3
POLL = 2
LUX_CHANGE = 0.15
DBUS_BUS = 'unix:path=/run/user/1000/bus'
DBUS_ENV = {**os.environ, 'DBUS_SESSION_BUS_ADDRESS': DBUS_BUS}


def read_sysfs(path):
    with open(path) as f:
        return int(f.read().strip())


def log_lux(lux):
    return math.log10(max(lux, 1))


def lux_to_screen(lux):
    t = log_lux(lux)
    frac = max(0.0, min(1.0, (t - 3.5) / 1.8))
    return round(SCREEN_MIN + frac * (SCREEN_MAX - SCREEN_MIN))


def lux_to_kbd(lux):
    t = log_lux(lux)
    frac = 1.0 - (t - 3.5) / 1.8
    return max(0, min(KBD_MAX, round(frac * KBD_MAX)))


def gdbus(method, *args):
    subprocess.run(
        ['runuser', '-u', 'dechros', '--',
         'gdbus', 'call', '--session',
         '--dest', 'org.gnome.Mutter.DisplayConfig',
         '--object-path', '/org/gnome/Mutter/DisplayConfig',
         '--method', method] + list(args),
        env=DBUS_ENV, capture_output=True, timeout=5)


def get_serial():
    r = subprocess.run(
        ['runuser', '-u', 'dechros', '--',
         'gdbus', 'call', '--session',
         '--dest', 'org.gnome.Mutter.DisplayConfig',
         '--object-path', '/org/gnome/Mutter/DisplayConfig',
         '--method', 'org.freedesktop.DBus.Properties.Get',
         'org.gnome.Mutter.DisplayConfig', 'Backlight'],
        env=DBUS_ENV, capture_output=True, text=True, timeout=5)
    if r.returncode == 0 and 'uint32' in r.stdout:
        return r.stdout.split('uint32 ')[1].split(',')[0]
    return None


def set_screen(val):
    serial = get_serial()
    if serial:
        gdbus('org.gnome.Mutter.DisplayConfig.SetBacklight',
              serial, 'eDP-1', str(val))


def set_kbd(val):
    try:
        with open(KBD_BL, 'w') as f:
            f.write(str(val))
    except Exception:
        pass


def disable_shell_auto():
    subprocess.run(
        ['runuser', '-u', 'dechros', '--',
         'gdbus', 'call', '--session',
         '--dest', 'org.gnome.Shell',
         '--object-path', '/org/gnome/Shell/Brightness',
         '--method', 'org.gnome.Shell.Brightness.SetAutoBrightnessTarget',
         '--', '-1.0'],
        env=DBUS_ENV, capture_output=True, timeout=5)


def main():
    disable_shell_auto()
    last_lux = read_sysfs(ALS)
    screen_val = lux_to_screen(last_lux)
    kbd_val = lux_to_kbd(last_lux)
    set_screen(screen_val)
    set_kbd(kbd_val)

    while True:
        try:
            lux = read_sysfs(ALS)
            if abs(log_lux(lux) - log_lux(last_lux)) >= LUX_CHANGE:
                last_lux = lux
                screen_val = lux_to_screen(lux)
                kbd_val = lux_to_kbd(lux)
                set_screen(screen_val)
                set_kbd(kbd_val)
        except Exception:
            pass
        time.sleep(POLL)


if __name__ == '__main__':
    main()
