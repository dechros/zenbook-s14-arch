#!/bin/bash
set -e

echo "=== Setting up CachyOS repositories ==="
if ! pacman -Q cachyos-keyring &>/dev/null; then
    TMP=$(mktemp -d)
    curl -o "$TMP/cachyos-repo.tar.xz" https://mirror.cachyos.org/cachyos-repo.tar.xz
    tar xf "$TMP/cachyos-repo.tar.xz" -C "$TMP"
    (cd "$TMP/cachyos-repo" && sudo ./cachyos-repo.sh)
    rm -rf "$TMP"
fi

echo "=== Enabling x86_64_v3 architecture ==="
if ! grep -q 'x86_64_v3' /etc/pacman.conf; then
    sudo sed -i 's/^Architecture = auto$/Architecture = auto x86_64_v3/' /etc/pacman.conf
fi

echo "=== Adding cachyos-v3 repository ==="
if ! grep -q '^\[cachyos-v3\]' /etc/pacman.conf; then
    sudo sed -i '/^\[core\]/i # CachyOS v3 repo\n[cachyos-v3]\nInclude = \/etc\/pacman.d\/cachyos-v3-mirrorlist\n' /etc/pacman.conf
fi

sudo pacman -Sy

echo "=== Installing CachyOS kernel ==="
sudo pacman -S --needed --noconfirm linux-cachyos linux-cachyos-headers
