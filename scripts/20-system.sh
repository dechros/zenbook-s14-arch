#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "=== Copying system files ==="
sudo cp -r "$REPO_DIR/system/etc/"* /etc/
if [[ -d "$REPO_DIR/system/usr" ]]; then
    sudo cp -r "$REPO_DIR/system/usr/"* /usr/
fi
if [[ -d "$REPO_DIR/system/boot" && -d /boot/loader ]]; then
    sudo cp -r "$REPO_DIR/system/boot/"* /boot/
fi

echo "=== Building CachyOS UKI ==="
sudo mkinitcpio -p linux-cachyos

echo "=== Enabling system services ==="
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger
# anydesk: always-on backend so the relay stays connected; the system-sleep
# hook (30-anydesk-reconnect) restarts it on resume to recover the relay.
# Self-heal: restart.conf drop-in adds Restart=always (anydesk SIGABRT-crashes
# periodically and the stock unit had no Restart -> needed manual restart).
# anydesk-watchdog.timer (every 2min) catches the "process alive but relay dead"
# case that Restart can't see, with a 90s startup guard to avoid restart loops.
sudo systemctl enable anydesk.service || true
sudo systemctl enable anydesk-watchdog.timer || true

# mirror auto-maintenance: keep both repos' mirrorlists ranked by speed so
# updates don't fail on a slow mirror. reflector.timer (Arch, weekly, config in
# /etc/xdg/reflector/reflector.conf) + cachyos-rate-mirrors.timer (CachyOS).
sudo systemctl enable --now reflector.timer || true
sudo systemctl enable --now cachyos-rate-mirrors.timer || true

# WiFi backend = iwd (config: NetworkManager/conf.d/wifi-backend.conf). With
# wpa_supplicant the boot DHCP stalled ~14s; iwd has the link ready when DHCP
# starts so the first request succeeds (~0.2s). Mask wpa_supplicant so it can't
# race iwd for the device.
sudo systemctl enable iwd.service || true
sudo systemctl mask wpa_supplicant.service || true

# systemd 261 auto-enables systemd-pcrlogin@ (TPM measurement of user records).
# We don't use measured user records; on this TPM it fails every boot with
# "No space left on device" (TPM NV full) and shows as a failed unit. Mask it.
# (Unrelated to TPM2 disk unlock, which uses boot-stack PCRs, not pcrlogin.)
sudo systemctl mask systemd-pcrlogin@.service || true

# freeze-capture: CS:GO hard-freeze teshisi (drm/xe #7513 suphesi). Boot'ta
# onceki boot temiz kapanmadiysa o boot'un xe/drm loglarini /var/log/freeze-capture
# altina kaydeder. (journald.conf.d/fast-sync + sysctl.d/99-freeze-debug ile birlikte.)
sudo systemctl enable freeze-capture.service || true
