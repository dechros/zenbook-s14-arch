#!/bin/bash
set -euo pipefail
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# AppGrid launcher customization (dechros): clean grid. No search bar, no
# category bar, no dividers/border, no top header gap, typing doesn't trigger
# search. Since 1.9.3 the QML is compiled into the plugin .so, so a ~/.local
# override no longer works. We rebuild the AUR package with our patches
# (makepkg -o; patch; makepkg -e -si) and pin it with IgnorePkg.

PKG=plasma6-applets-appgrid
BUILD_DIR="${BUILD_DIR:-$(mktemp -d -t appgrid-build.XXXXXX)}"

echo "=== Building $PKG with clean-grid patches in $BUILD_DIR ==="
cd "$BUILD_DIR"
rm -rf "$PKG"
git clone -q "https://aur.archlinux.org/$PKG.git"
cd "$PKG"

# Fetch + extract sources, install build deps (no build yet).
makepkg -o -s --noconfirm

UI_DIR=$(echo src/plasma6-applet-appgrid-*/package/contents/ui)
for p in GridPanel AppGridView CategoryGridView; do
    if patch -p1 -N -d "$UI_DIR" < "$REPO_DIR/appgrid/$p.qml.patch"; then
        echo "  patched $p.qml"
    else
        echo "ERROR: $p.qml patch failed; upstream changed, re-create the patch." >&2
        exit 1
    fi
done

# Build from the patched tree (-e: skip extraction) and install.
makepkg -e -si --noconfirm

# Old ~/.local override is ignored since 1.9.3 and only confuses; remove it.
rm -rf "$HOME/.local/share/plasma/plasmoids/dev.xarbit.appgrid"
rm -rf "$HOME/.cache/plasmashell/qmlcache" 2>/dev/null || true

# Keep yay/pacman -Syu from replacing the patched build.
if ! grep -qE "^\s*IgnorePkg\s*=.*\b$PKG\b" /etc/pacman.conf; then
    if grep -qE '^\s*IgnorePkg\s*=' /etc/pacman.conf; then
        sudo sed -i -E "/^\s*IgnorePkg\s*=/ s/$/ $PKG/" /etc/pacman.conf
    else
        sudo sed -i "/^\[options\]/a IgnorePkg = $PKG" /etc/pacman.conf
    fi
    echo "  added $PKG to IgnorePkg in /etc/pacman.conf"
fi

echo "=== Done. Restart plasmashell to apply: systemctl --user restart plasma-plasmashell ==="
