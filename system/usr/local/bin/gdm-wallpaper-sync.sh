#!/bin/bash
set -u

sync_now() {
    local uri
    uri=$(gsettings get org.gnome.desktop.background picture-uri-dark | sed "s/^'//;s/'$//")
    [[ -z "$uri" ]] && return
    sudo -n /usr/local/bin/gdm-wallpaper-update "$uri" || true
}

sync_now
gsettings monitor org.gnome.desktop.background picture-uri-dark | while read -r _; do
    sync_now
done
