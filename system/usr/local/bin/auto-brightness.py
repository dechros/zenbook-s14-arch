#!/usr/bin/env python3
import math
import os
import time

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
SCREEN_BL = '/sys/class/backlight/intel_backlight/brightness'
SCREEN_MIN = 4
SCREEN_MAX = 400
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = 3
POLL = 2
LUX_CHANGE = 0.15


def read_sysfs(path):
    with open(path) as f:
        return int(f.read().strip())


def write_sysfs(path, val):
    with open(path, 'w') as f:
        f.write(str(val))


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


def disable_shell_auto():
    import subprocess
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
    last_lux = read_sysfs(ALS)
    screen_val = lux_to_screen(last_lux)
    kbd_val = lux_to_kbd(last_lux)
    write_sysfs(SCREEN_BL, screen_val)
    write_sysfs(KBD_BL, kbd_val)

    while True:
        try:
            lux = read_sysfs(ALS)
            if abs(log_lux(lux) - log_lux(last_lux)) >= LUX_CHANGE:
                last_lux = lux
                screen_val = lux_to_screen(lux)
                kbd_val = lux_to_kbd(lux)
                write_sysfs(SCREEN_BL, screen_val)
                write_sysfs(KBD_BL, kbd_val)
        except Exception:
            pass
        time.sleep(POLL)


if __name__ == '__main__':
    main()
