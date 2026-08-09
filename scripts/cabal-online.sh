#!/bin/bash
# CABAL Online (EU) — PlayThisGame — Wine setup (Lunar Lake / KDE Wayland)
#
# Why this is special: the official EU client (cabaleu.playthisgame.com ->
# 11132014_EU_Setup.exe) has a 2014 base; on first launch it self-updates to the
# current launcher and switches to the new patch/info hosts (c1eu.cdn /
# c1eu.info01 .playthisgame.com). BUT c1eu.info01.playthisgame.com has been
# removed from DNS (NXDOMAIN) -> the launcher hangs there and shows "Update Fail".
# Fix: map that dead host to 127.0.0.1 and run a tiny local proxy
# (cabal-patch-proxy.service) that forwards the requests to the live CDN
# (c1eu.cdn.playthisgame.com). The launcher then fetches the manifest and patches
# fully. GameGuard passes under Wine; the character screen needs native d3dx9;
# text rendering needs corefonts+tahoma.
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PREFIX="$HOME/Games/cabal-online"
GAMEDIR="$PREFIX/drive_c/Program Files (x86)/CABAL Online (EU)"

echo "=== 1. Wine + winetricks + 32-bit runtime (multilib required) ==="
sudo pacman -S --needed --noconfirm wine winetricks wine-mono wine-gecko \
    lib32-gnutls lib32-alsa-lib lib32-alsa-plugins lib32-libpulse \
    lib32-mpg123 lib32-giflib lib32-libjpeg-turbo lib32-openal lib32-libxcomposite

echo "=== 2. Redirect the dead info host -> local patch proxy ==="
# /etc/hosts entry (persistent) + proxy service (auto on boot, :80 -> live CDN)
grep -q 'c1eu.info01.playthisgame.com' /etc/hosts || \
    echo '127.0.0.1 c1eu.info01.playthisgame.com' | sudo tee -a /etc/hosts >/dev/null
sudo systemctl enable --now cabal-patch-proxy.service

echo "=== 3. Create win64 prefix (wine 11.x new-WoW64: win32 prefix unsupported) ==="
if [[ ! -d "$PREFIX" ]]; then
    WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u
fi

echo "=== 4. Fonts (text render) + native d3dx9/d3dcompiler (character screen) ==="
WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml=" \
    winetricks -q corefonts tahoma d3dx9 d3dcompiler_43 d3dcompiler_47

cat <<EOF

=== 5. MANUAL steps (cannot be automated) ===
  a) Register / log in at cabaleu.playthisgame.com and download the client
     installer (11132014_EU_Setup.exe, ~2GB).
  b) Install:
     WINEPREFIX="$PREFIX" WINEARCH=win64 wine ~/Downloads/11132014_EU_Setup.exe
  c) Start the launcher; thanks to the proxy it patches (v677 -> current,
     downloads ~11GB), "Update Complete" -> START -> log in with your
     PlayThisGame account.
  Menu entry (hi-def logo): user/.local/share/applications/cabal-online-eu.desktop
  Launcher: ~/.local/bin/cabal-online-eu.sh  (proxy service runs in the background)

Note: the 11GB game data is not tracked in the repo; it downloads via the
launcher patch.
EOF
