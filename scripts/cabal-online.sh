#!/bin/bash
# CABAL Online (EU) — PlayThisGame — Wine kurulumu (Lunar Lake / KDE Wayland)
#
# Neden ozel: resmi EU client (cabaleu.playthisgame.com -> 11132014_EU_Setup.exe)
# 2014 base'li; ilk acilista kendini guncel launcher'a cevirir ve yeni patch/info
# host'larina (c1eu.cdn / c1eu.info01 .playthisgame.com) gecer. ANCAK
# c1eu.info01.playthisgame.com DNS'ten silinmis (NXDOMAIN) -> launcher orada
# takilip "Update Fail" verir. Cozum: o olu host'u 127.0.0.1'e map edip kucuk bir
# yerel proxy (cabal-patch-proxy.service) ile istekleri canli CDN'e
# (c1eu.cdn.playthisgame.com) forward etmek. Boylece launcher manifest'i alip
# tam patch'lenir. GameGuard Wine'da gecer; karakter ekrani icin native d3dx9
# gerekir; text render icin corefonts+tahoma gerekir.
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PREFIX="$HOME/Games/cabal-online"
GAMEDIR="$PREFIX/drive_c/Program Files (x86)/CABAL Online (EU)"

echo "=== 1. Wine + winetricks + 32-bit runtime (multilib gerekli) ==="
sudo pacman -S --needed --noconfirm wine winetricks wine-mono wine-gecko \
    lib32-gnutls lib32-alsa-lib lib32-alsa-plugins lib32-libpulse \
    lib32-mpg123 lib32-giflib lib32-libjpeg-turbo lib32-openal lib32-libxcomposite

echo "=== 2. Olu info host'unu -> yerel patch proxy'ye yonlendir ==="
# /etc/hosts kaydi (kalici) + proxy servisi (boot'ta otomatik, :80 -> canli CDN)
grep -q 'c1eu.info01.playthisgame.com' /etc/hosts || \
    echo '127.0.0.1 c1eu.info01.playthisgame.com' | sudo tee -a /etc/hosts >/dev/null
sudo systemctl enable --now cabal-patch-proxy.service

echo "=== 3. win64 prefix olustur (wine 11.x new-WoW64: win32 prefix desteklenmez) ==="
if [[ ! -d "$PREFIX" ]]; then
    WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u
fi

echo "=== 4. Fontlar (text render) + native d3dx9/d3dcompiler (karakter ekrani) ==="
WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml=" \
    winetricks -q corefonts tahoma d3dx9 d3dcompiler_43 d3dcompiler_47

cat <<EOF

=== 5. MANUEL adimlar (otomatiklestirilemez) ===
  a) cabaleu.playthisgame.com adresine kayit ol / giris yap, client installer'i indir
     (11132014_EU_Setup.exe, ~2GB).
  b) Kur:
     WINEPREFIX="$PREFIX" WINEARCH=win64 wine ~/Downloads/11132014_EU_Setup.exe
  c) Launcher'i baslat; proxy sayesinde patch'lenir (v677 -> guncel, ~11GB indirir),
     "Update Complete" -> START -> PlayThisGame hesabinla giris.
  Menu girdisi (hi-def logo): user/.local/share/applications/cabal-online-eu.desktop
  Baslatici: ~/.local/bin/cabal-online-eu.sh  (proxy servisi arka planda otomatik)

Not: 11GB oyun verisi repoda tutulmaz; launcher patch'iyle iner.
EOF
