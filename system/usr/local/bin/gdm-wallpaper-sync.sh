#!/bin/bash
set -u

unq() { sed "s/^'//;s/'$//"; }

sync_settings() {
    local uri icon cursor speed scale
    uri=$(gsettings get org.gnome.desktop.background picture-uri-dark | unq)
    icon=$(gsettings get org.gnome.desktop.interface icon-theme | unq)
    cursor=$(gsettings get org.gnome.desktop.interface cursor-theme | unq)
    speed=$(gsettings get org.gnome.desktop.peripherals.mouse speed)
    scale=$(gsettings get org.gnome.desktop.interface text-scaling-factor)
    [[ -z "$uri" ]] && return
    sudo -n /usr/local/bin/gdm-wallpaper-update "$uri" "$icon" "$cursor" "$speed" "$scale" || true
}

sync_monitors() {
    local f="$HOME/.config/monitors.xml"
    [[ -f "$f" ]] && sudo -n /usr/local/bin/gdm-wallpaper-update monitors "$f" || true
}

sync_all() {
    sync_settings
    sync_monitors
}

sync_all

(
    gsettings monitor org.gnome.desktop.background picture-uri-dark
    gsettings monitor org.gnome.desktop.interface icon-theme
    gsettings monitor org.gnome.desktop.interface cursor-theme
    gsettings monitor org.gnome.desktop.interface text-scaling-factor
    gsettings monitor org.gnome.desktop.peripherals.mouse speed
) | while read -r _; do
    sync_settings
done &

if command -v inotifywait &>/dev/null; then
    while inotifywait -qq -e close_write -e moved_to "$HOME/.config/monitors.xml" 2>/dev/null; do
        sync_monitors
    done
fi

wait
