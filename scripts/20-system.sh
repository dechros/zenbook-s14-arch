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
sudo systemctl enable --now cachyos-rate-mirrors.timer || true

sudo systemctl enable --now fwupd-refresh.timer || true

# iwd is the Wi-Fi backend; masked wpa_supplicant cannot race it for the device.
sudo systemctl enable iwd.service || true
sudo systemctl mask wpa_supplicant.service || true

# NvPCR units fail every boot (TPM NV space is full) and nothing uses them.
sudo systemctl mask systemd-pcrlogin@.service || true
sudo systemctl mask systemd-pcrproduct.service || true
sudo systemctl mask systemd-tpm2-setup-early.service || true

# Saves the previous boot's logs to /var/log/freeze-capture after an unclean shutdown.
sudo systemctl enable freeze-capture.service || true
