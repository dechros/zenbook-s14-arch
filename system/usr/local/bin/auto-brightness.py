#!/usr/bin/env python3
import json
import math
import os
import subprocess
import time
import glob

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
SCREEN_BL = '/sys/class/backlight/intel_backlight/brightness'
SCREEN_MAX = '/sys/class/backlight/intel_backlight/max_brightness'
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = '/sys/class/leds/asus::kbd_backlight/max_brightness'
STATE_DIR = '/var/lib/auto-brightness'
CURVE_FILE = os.path.join(STATE_DIR, 'curve.json')

POLL_SEC = 2
BUCKET = 0.3
USER_COOLDOWN = 20
LUX_DELTA = 0.15


def read_int(path):
    with open(path) as f:
        return int(f.read().strip())


def log_lux(raw):
    return math.log10(max(raw, 1))


def bucket_of(raw):
    return round(log_lux(raw) / BUCKET) * BUCKET


def load_state():
    os.makedirs(STATE_DIR, exist_ok=True)
    try:
        with open(CURVE_FILE) as f:
            d = json.load(f)
            return (d.get('screen', {}), d.get('kbd', {}),
                    d.get('cal', {'low': None, 'high': None}))
    except Exception:
        return {}, {}, {'low': None, 'high': None}


def save_state(screen, kbd, cal):
    tmp = CURVE_FILE + '.tmp'
    with open(tmp, 'w') as f:
        json.dump({'screen': screen, 'kbd': kbd, 'cal': cal}, f, indent=2)
    os.replace(tmp, CURVE_FILE)


def calibrate(cal, target, sysfs_pct):
    point = [round(target, 3), round(sysfs_pct, 3)]
    low, high = cal.get('low'), cal.get('high')
    if low is None or target < low[0] - 0.05:
        cal['low'] = point
    elif high is None or target > high[0] + 0.05:
        cal['high'] = point
    else:
        if low and abs(target - low[0]) < abs(target - (high[0] if high else 1)):
            cal['low'] = point
        elif high:
            cal['high'] = point


def sysfs_pct_to_target(sysfs_pct, cal):
    low, high = cal.get('low'), cal.get('high')
    if not low or not high or high[0] - low[0] < 0.05:
        return max(0.0, min(1.0, sysfs_pct))
    slope = (high[1] - low[1]) / (high[0] - low[0])
    if slope < 0.05:
        return max(0.0, min(1.0, sysfs_pct))
    target = low[0] + (sysfs_pct - low[1]) / slope
    return max(0.0, min(1.0, target))


def predict(curve, raw, default_fn):
    if not curve:
        return default_fn(log_lux(raw))
    b = bucket_of(raw)
    keys = sorted(float(k) for k in curve.keys())
    if b <= keys[0]:
        return curve[f'{keys[0]:.2f}']
    if b >= keys[-1]:
        return curve[f'{keys[-1]:.2f}']
    for i in range(len(keys) - 1):
        a, c = keys[i], keys[i + 1]
        if a <= b <= c:
            t = (b - a) / (c - a) if c > a else 0
            va = curve[f'{a:.2f}']
            vc = curve[f'{c:.2f}']
            return va + t * (vc - va)
    return curve[f'{keys[-1]:.2f}']


def snap(curve, raw, fraction):
    b = bucket_of(raw)
    curve[f'{b:.2f}'] = max(0.0, min(1.0, fraction))


def default_screen(log10_raw):
    return max(0.15, min(1.0, 0.15 + (log10_raw - 3.5) / 2.5 * 0.85))


def default_kbd(log10_raw):
    return max(0.0, min(1.0, 1.0 - (log10_raw - 3.5) / 1.5))


def find_session_bus():
    try:
        result = subprocess.run(
            ['loginctl', 'list-sessions', '--no-legend'],
            capture_output=True, text=True)
        for line in result.stdout.strip().split('\n'):
            parts = line.split()
            if len(parts) >= 3:
                uid = parts[1]
                if int(uid) >= 1000 and os.path.exists(f'/run/user/{uid}/bus'):
                    return f'unix:path=/run/user/{uid}/bus', uid
    except Exception:
        pass
    return None, None


def set_screen_target(target):
    bus, uid = find_session_bus()
    if not bus:
        return
    env = os.environ.copy()
    env['DBUS_SESSION_BUS_ADDRESS'] = bus
    subprocess.run([
        'gdbus', 'call', '--session',
        '--dest', 'org.gnome.Shell',
        '--object-path', '/org/gnome/Shell/Brightness',
        '--method', 'org.gnome.Shell.Brightness.SetAutoBrightnessTarget',
        f'{target:.3f}',
    ], check=False, capture_output=True, timeout=5, env=env)


def set_kbd_level(level):
    try:
        with open(KBD_BL, 'w') as f:
            f.write(str(level))
        return True
    except Exception:
        return False


def main():
    screen_curve, kbd_curve, cal = load_state()
    screen_max = read_int(SCREEN_MAX)
    kbd_max = read_int(KBD_MAX)

    last_raw = read_int(ALS)
    last_screen_set = read_int(SCREEN_BL)
    last_kbd_set = read_int(KBD_BL)
    user_change_until = 0
    last_target = -1

    while True:
        try:
            raw = read_int(ALS)
            cur_screen = read_int(SCREEN_BL)
            cur_kbd = read_int(KBD_BL)
            now = time.time()

            screen_user_delta = cur_screen - last_screen_set
            kbd_user_delta = cur_kbd - last_kbd_set

            if abs(screen_user_delta) > screen_max * 0.03:
                snap(screen_curve, raw, cur_screen / screen_max)
                save_state(screen_curve, kbd_curve, cal)
                user_change_until = now + USER_COOLDOWN
                last_screen_set = cur_screen

            if abs(kbd_user_delta) >= 1:
                snap(kbd_curve, raw, cur_kbd / kbd_max)
                save_state(screen_curve, kbd_curve, cal)
                user_change_until = now + USER_COOLDOWN
                last_kbd_set = cur_kbd

            if now >= user_change_until:
                lx_change = abs(log_lux(raw) - log_lux(last_raw))
                if lx_change >= LUX_DELTA or last_target < 0:
                    desired_sysfs_pct = predict(screen_curve, raw, default_screen)
                    screen_target = sysfs_pct_to_target(desired_sysfs_pct, cal)
                    kbd_target = predict(kbd_curve, raw, default_kbd)

                    if abs(screen_target - last_target) > 0.02 or last_target < 0:
                        set_screen_target(screen_target)
                        last_target = screen_target
                        time.sleep(1)
                        resulting = read_int(SCREEN_BL)
                        last_screen_set = resulting
                        calibrate(cal, screen_target, resulting / screen_max)
                        save_state(screen_curve, kbd_curve, cal)

                    kbd_level = round(kbd_target * kbd_max)
                    if kbd_level != cur_kbd:
                        if set_kbd_level(kbd_level):
                            last_kbd_set = kbd_level

                    last_raw = raw
        except Exception:
            pass
        time.sleep(POLL_SEC)


if __name__ == '__main__':
    main()
