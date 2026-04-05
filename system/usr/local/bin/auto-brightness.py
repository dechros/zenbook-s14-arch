#!/usr/bin/env python3
"""Self-learning ambient brightness controller for screen and keyboard.

Screen: changes target via org.gnome.Shell.Brightness.SetAutoBrightnessTarget.
Keyboard: writes /sys/class/leds/asus::kbd_backlight/brightness directly.

Observes user manual adjustments and nudges per-lux-bucket curves.
"""
import json
import math
import os
import subprocess
import time

ALS = '/sys/bus/iio/devices/iio:device2/in_illuminance_raw'
SCREEN_BL = '/sys/class/backlight/intel_backlight/brightness'
SCREEN_MAX = '/sys/class/backlight/intel_backlight/max_brightness'
KBD_BL = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = '/sys/class/leds/asus::kbd_backlight/max_brightness'
STATE_DIR = os.path.expanduser('~/.local/state/auto-brightness')
CURVE_FILE = os.path.join(STATE_DIR, 'curve.json')

POLL_SEC = 2
BUCKET = 0.3          # log10 lux bucket width
NUDGE = 0.05          # fractional curve adjustment per user correction
USER_COOLDOWN = 20    # seconds: skip auto-adjust after user change
LUX_DELTA = 0.15      # log10 change required to trigger re-evaluation


def read_int(path):
    with open(path) as f:
        return int(f.read().strip())


def log_lux(raw):
    return math.log10(max(raw, 1))


def bucket_of(raw):
    return round(log_lux(raw) / BUCKET) * BUCKET


def load_curves():
    os.makedirs(STATE_DIR, exist_ok=True)
    try:
        with open(CURVE_FILE) as f:
            d = json.load(f)
            return d.get('screen', {}), d.get('kbd', {})
    except Exception:
        return {}, {}


def save_curves(screen, kbd):
    tmp = CURVE_FILE + '.tmp'
    with open(tmp, 'w') as f:
        json.dump({'screen': screen, 'kbd': kbd}, f, indent=2)
    os.replace(tmp, CURVE_FILE)


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


def nudge(curve, raw, direction, default_fn):
    """Move curve[bucket] by direction*NUDGE toward 0 or 1."""
    b = bucket_of(raw)
    k = f'{b:.2f}'
    cur = curve.get(k, default_fn(log_lux(raw)))
    new = max(0.0, min(1.0, cur + direction * NUDGE))
    curve[k] = new


def default_screen(log10_raw):
    # raw sensor, scale=0.001. covered=3k, dark=18k, indoor=100k, day=1M.
    # log10: 3.5, 4.3, 5.0, 6.0 -> target: 0.15 .. 1.0
    return max(0.15, min(1.0, 0.15 + (log10_raw - 3.5) / 2.5 * 0.85))


def default_kbd(log10_raw):
    # dark (log~3.5) -> full kbd; indoor (log~5.0) -> off
    return max(0.0, min(1.0, 1.0 - (log10_raw - 3.5) / 1.5))


def set_screen_target(target):
    subprocess.run([
        'gdbus', 'call', '--session',
        '--dest', 'org.gnome.Shell',
        '--object-path', '/org/gnome/Shell/Brightness',
        '--method', 'org.gnome.Shell.Brightness.SetAutoBrightnessTarget',
        f'{target:.3f}',
    ], check=False, capture_output=True, timeout=5)


def set_kbd_level(level):
    try:
        with open(KBD_BL, 'w') as f:
            f.write(str(level))
        return True
    except Exception:
        return False


def main():
    screen_curve, kbd_curve = load_curves()
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
                direction = 1 if screen_user_delta > 0 else -1
                nudge(screen_curve, raw, direction, default_screen)
                save_curves(screen_curve, kbd_curve)
                user_change_until = now + USER_COOLDOWN
                last_screen_set = cur_screen
                print(f'learn screen: lux={raw} dir={direction}', flush=True)

            if abs(kbd_user_delta) >= 1:
                direction = 1 if kbd_user_delta > 0 else -1
                nudge(kbd_curve, raw, direction, default_kbd)
                save_curves(screen_curve, kbd_curve)
                user_change_until = now + USER_COOLDOWN
                last_kbd_set = cur_kbd
                print(f'learn kbd: lux={raw} dir={direction}', flush=True)

            if now >= user_change_until:
                lx_change = abs(log_lux(raw) - log_lux(last_raw))
                if lx_change >= LUX_DELTA or last_target < 0:
                    screen_target = predict(screen_curve, raw, default_screen)
                    kbd_target = predict(kbd_curve, raw, default_kbd)

                    if abs(screen_target - last_target) > 0.02 or last_target < 0:
                        set_screen_target(screen_target)
                        last_target = screen_target
                        time.sleep(1)
                        last_screen_set = read_int(SCREEN_BL)

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
