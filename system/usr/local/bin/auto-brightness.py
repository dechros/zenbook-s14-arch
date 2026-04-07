#!/usr/bin/env python3
import json
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
CURVE_FILE = '/var/lib/auto-brightness/curve.json'


def read_sysfs(path):
    with open(path) as f:
        return int(f.read().strip())


def write_sysfs(path, val):
    with open(path, 'w') as f:
        f.write(str(val))


def log_lux(lux):
    return math.log10(max(lux, 1))


def default_screen(lux):
    t = log_lux(lux)
    frac = max(0.0, min(1.0, (t - 3.5) / 1.8))
    return round(SCREEN_MIN + frac * (SCREEN_MAX - SCREEN_MIN))


def default_kbd(lux):
    t = log_lux(lux)
    frac = 1.0 - (t - 3.5) / 1.8
    return max(0, min(KBD_MAX, round(frac * KBD_MAX)))


def interp(points, lux):
    if not points:
        return None
    t = log_lux(lux)
    keys = sorted(points.keys(), key=float)
    if len(keys) == 1:
        return points[keys[0]]
    if t <= float(keys[0]):
        return points[keys[0]]
    if t >= float(keys[-1]):
        return points[keys[-1]]
    for i in range(len(keys) - 1):
        a, b = float(keys[i]), float(keys[i + 1])
        if a <= t <= b:
            r = (t - a) / (b - a)
            return round(points[keys[i]] + r * (points[keys[i + 1]] - points[keys[i]]))
    return points[keys[-1]]


def snap(points, lux, val):
    t = f'{log_lux(lux):.1f}'
    points[t] = val


def load_curve():
    os.makedirs(os.path.dirname(CURVE_FILE), exist_ok=True)
    try:
        with open(CURVE_FILE) as f:
            d = json.load(f)
            return d.get('screen', {}), d.get('kbd', {})
    except Exception:
        return {}, {}


def save_curve(screen, kbd):
    tmp = CURVE_FILE + '.tmp'
    with open(tmp, 'w') as f:
        json.dump({'screen': screen, 'kbd': kbd}, f, indent=2)
    os.replace(tmp, CURVE_FILE)


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


def predict_screen(screen_curve, lux):
    v = interp(screen_curve, lux)
    return v if v is not None else default_screen(lux)


def predict_kbd(kbd_curve, lux):
    v = interp(kbd_curve, lux)
    return v if v is not None else default_kbd(lux)


def main():
    disable_shell_auto()
    screen_curve, kbd_curve = load_curve()
    last_lux = read_sysfs(ALS)
    last_screen_set = read_sysfs(SCREEN_BL)
    last_kbd_set = read_sysfs(KBD_BL)
    screen_locked = False
    kbd_locked = False

    while True:
        try:
            lux = read_sysfs(ALS)
            lux_changed = abs(log_lux(lux) - log_lux(last_lux)) >= LUX_CHANGE

            cur_screen = read_sysfs(SCREEN_BL)
            if abs(cur_screen - last_screen_set) > SCREEN_MAX * 0.03:
                snap(screen_curve, lux, cur_screen)
                save_curve(screen_curve, kbd_curve)
                screen_locked = True

            cur_kbd = read_sysfs(KBD_BL)
            if cur_kbd != last_kbd_set:
                snap(kbd_curve, lux, cur_kbd)
                save_curve(screen_curve, kbd_curve)
                kbd_locked = True

            if lux_changed:
                screen_locked = False
                kbd_locked = False
                last_lux = lux

            if not screen_locked:
                screen = predict_screen(screen_curve, lux)
                if screen != last_screen_set:
                    write_sysfs(SCREEN_BL, screen)
                    last_screen_set = screen

            if not kbd_locked:
                kbd = predict_kbd(kbd_curve, lux)
                if kbd != last_kbd_set:
                    write_sysfs(KBD_BL, kbd)
                    last_kbd_set = kbd
        except Exception:
            pass
        time.sleep(POLL)


if __name__ == '__main__':
    main()
