#!/usr/bin/env python3
import math
import time

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
SCREEN_BL = '/sys/class/backlight/intel_backlight/brightness'
SCREEN_MIN = 4
SCREEN_MAX = 400
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = 3
POLL = 2


def read_sysfs(path):
    with open(path) as f:
        return int(f.read().strip())


def write_sysfs(path, val):
    with open(path, 'w') as f:
        f.write(str(val))


def lux_to_screen(lux):
    if lux <= 0:
        lux = 1
    t = math.log10(lux)
    frac = (t - 3.5) / 1.8
    frac = max(0.0, min(1.0, frac))
    return round(SCREEN_MIN + frac * (SCREEN_MAX - SCREEN_MIN))


def lux_to_kbd(lux):
    if lux <= 0:
        lux = 1
    t = math.log10(lux)
    frac = 1.0 - (t - 3.5) / 1.8
    return max(0, min(KBD_MAX, round(frac * KBD_MAX)))


def disable_shell_auto():
    import subprocess, os
    try:
        subprocess.run(
            ['runuser', '-u', 'dechros', '--',
             'gdbus', 'call', '--session',
             '--dest', 'org.gnome.Shell',
             '--object-path', '/org/gnome/Shell/Brightness',
             '--method', 'org.gnome.Shell.Brightness.SetAutoBrightnessTarget',
             '--', '-1.0'],
            env={**os.environ, 'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus'},
            capture_output=True, timeout=5)
    except Exception:
        pass


def main():
    disable_shell_auto()
    prev_screen = -1
    prev_kbd = -1

    while True:
        try:
            lux = read_sysfs(ALS)
            screen = lux_to_screen(lux)
            kbd = lux_to_kbd(lux)

            if screen != prev_screen:
                write_sysfs(SCREEN_BL, screen)
                prev_screen = screen

            if kbd != prev_kbd:
                write_sysfs(KBD_BL, kbd)
                prev_kbd = kbd
        except Exception:
            pass
        time.sleep(POLL)


if __name__ == '__main__':
    main()
