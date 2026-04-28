#!/usr/bin/env python3
import time

SCREEN = '/sys/class/backlight/intel_backlight/brightness'
SCREEN_MAX = '/sys/class/backlight/intel_backlight/max_brightness'
KBD = '/sys/class/leds/asus::kbd_backlight/brightness'
KBD_MAX = '/sys/class/leds/asus::kbd_backlight/max_brightness'
POLL = 0.5

def read_int(path):
    with open(path) as f:
        return int(f.read().strip())

def write_int(path, value):
    with open(path, 'w') as f:
        f.write(str(value))

def main():
    screen_max = read_int(SCREEN_MAX)
    kbd_max = read_int(KBD_MAX)
    last_level = -1

    while True:
        try:
            screen = read_int(SCREEN)
            frac = screen / screen_max
            kbd_level = round((1 - frac) * kbd_max)
            kbd_level = max(0, min(kbd_max, kbd_level))
            if kbd_level != last_level:
                write_int(KBD, kbd_level)
                last_level = kbd_level
        except Exception:
            pass
        time.sleep(POLL)

if __name__ == '__main__':
    main()
