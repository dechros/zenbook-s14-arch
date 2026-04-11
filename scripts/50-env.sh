#!/bin/bash
set -e

echo "=== Configuring /etc/environment ==="
if ! grep -q '^ELECTRON_OZONE_PLATFORM_HINT' /etc/environment; then
    echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' | sudo tee -a /etc/environment
fi
if ! grep -q '^SHELL=' /etc/environment; then
    echo 'SHELL=/usr/bin/zsh' | sudo tee -a /etc/environment
fi

echo "=== Setting locale ==="
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
sudo locale-gen
