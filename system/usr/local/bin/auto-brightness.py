#!/usr/bin/env python3
import math
import os
import subprocess
import time

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = 3
POLL = 2
DBUS_BUS = 'unix:path=/run/user/1000/bus'
DBUS_USER = 'dechros'


def read_sysfs(path):
    with open(path) as f:
        return int(f.read().strip())


def lux_to_screen(lux):
    if lux <= 0:
        lux = 1
    t = math.log10(lux)
    # raw 3000(dark)→target 0.0(sysfs 202), raw 200000(bright)→target 0.5(sysfs 400)
    return max(0.0, min(0.5, (t - 3.5) / 1.8 * 0.5))


def lux_to_kbd(lux):
    if lux <= 0:
        lux = 1
    t = math.log10(lux)
    # raw 3000(dark)→3, raw 200000(bright)→0
    return max(0, min(KBD_MAX, round(KBD_MAX * (1.0 - (t - 3.5) / 1.8))))


def set_screen(target):
    subprocess.run(
        ['runuser', '-u', DBUS_USER, '--',
         'gdbus', 'call', '--session',
         '--dest', 'org.gnome.Shell',
         '--object-path', '/org/gnome/Shell/Brightness',
         '--method', 'org.gnome.Shell.Brightness.SetAutoBrightnessTarget',
         f'{target:.4f}'],
        env={**os.environ, 'DBUS_SESSION_BUS_ADDRESS': DBUS_BUS},
        capture_output=True, timeout=5)


def set_kbd(level):
    try:
        with open(KBD_BL, 'w') as f:
            f.write(str(level))
    except Exception:
        pass


def main():
    prev_screen_target = -1.0
    prev_kbd = -1

    while True:
        try:
            lux = read_sysfs(ALS)
            screen_target = lux_to_screen(lux)
            kbd = lux_to_kbd(lux)

            if abs(screen_target - prev_screen_target) > 0.01:
                set_screen(screen_target)
                prev_screen_target = screen_target

            if kbd != prev_kbd:
                set_kbd(kbd)
                prev_kbd = kbd
        except Exception:
            pass
        time.sleep(POLL)


if __name__ == '__main__':
    main()
