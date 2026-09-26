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

# cachyos-repo.sh above sets these up itself, but it only runs when the keyring
# is missing. Without core-v3 and extra-v3 every core/extra package stays a
# generic x86_64 build and only CachyOS's own packages get the v3 optimisations.
echo "=== Adding the x86_64_v3 repositories ==="
if grep -q '^\[cachyos\]' /etc/pacman.conf; then
    before='^\[cachyos\]'
else
    before='^\[core\]'
fi
for repo in cachyos-v3 cachyos-core-v3 cachyos-extra-v3; do
    grep -q "^\[$repo\]" /etc/pacman.conf && continue
    sudo sed -i "/$before/i [$repo]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n" /etc/pacman.conf
done

echo "=== Rating CachyOS mirrors ==="
if ! command -v cachyos-rate-mirrors &>/dev/null; then
    sudo pacman -S --needed --noconfirm cachyos-rate-mirrors
fi
sudo cachyos-rate-mirrors

sudo pacman -Syu --noconfirm

# A package whose version matches in both repos is not replaced by -Syu, so
# reinstall everything that has a v3 build to move it off the generic one.
echo "=== Moving installed packages to their x86_64_v3 builds ==="
v3=$( (pacman -Slq cachyos-v3; pacman -Slq cachyos-core-v3; pacman -Slq cachyos-extra-v3) 2>/dev/null | sort -u)
mapfile -t generic < <(comm -12 <(pacman -Qqn | sort) <(echo "$v3") \
    | while read -r p; do [ "$(pacman -Qi "$p" | awk -F': ' '/^Architecture/{print $2}')" = x86_64 ] && echo "$p"; done)
[ ${#generic[@]} -gt 0 ] && sudo pacman -S --noconfirm "${generic[@]}"

echo "=== Installing CachyOS kernel ==="
sudo pacman -S --needed --noconfirm linux-cachyos linux-cachyos-headers
