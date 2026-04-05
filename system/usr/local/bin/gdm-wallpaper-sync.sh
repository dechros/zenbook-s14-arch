#!/bin/bash
set -u

g() { gsettings get "$1" "$2"; }

write_gdm_ini() {
    cat <<EOF
[org/gnome/desktop/background]
picture-uri=$(g org.gnome.desktop.background picture-uri)
picture-uri-dark=$(g org.gnome.desktop.background picture-uri-dark)
picture-options=$(g org.gnome.desktop.background picture-options)
primary-color=$(g org.gnome.desktop.background primary-color)
secondary-color=$(g org.gnome.desktop.background secondary-color)

[org/gnome/desktop/interface]
color-scheme=$(g org.gnome.desktop.interface color-scheme)
icon-theme=$(g org.gnome.desktop.interface icon-theme)
cursor-theme=$(g org.gnome.desktop.interface cursor-theme)
cursor-size=$(g org.gnome.desktop.interface cursor-size)
gtk-theme=$(g org.gnome.desktop.interface gtk-theme)
font-name=$(g org.gnome.desktop.interface font-name)
document-font-name=$(g org.gnome.desktop.interface document-font-name)
monospace-font-name=$(g org.gnome.desktop.interface monospace-font-name)
text-scaling-factor=$(g org.gnome.desktop.interface text-scaling-factor)
clock-format=$(g org.gnome.desktop.interface clock-format)
clock-show-seconds=$(g org.gnome.desktop.interface clock-show-seconds)
clock-show-weekday=$(g org.gnome.desktop.interface clock-show-weekday)

[org/gnome/desktop/peripherals/mouse]
speed=$(g org.gnome.desktop.peripherals.mouse speed)
natural-scroll=$(g org.gnome.desktop.peripherals.mouse natural-scroll)

[org/gnome/desktop/peripherals/touchpad]
speed=$(g org.gnome.desktop.peripherals.touchpad speed)
tap-to-click=$(g org.gnome.desktop.peripherals.touchpad tap-to-click)
natural-scroll=$(g org.gnome.desktop.peripherals.touchpad natural-scroll)
EOF
}

sync_settings() {
    write_gdm_ini | sudo -n /usr/local/bin/gdm-wallpaper-update || true
}

sync_monitors() {
    local f="$HOME/.config/monitors.xml"
    [[ -f "$f" ]] && sudo -n /usr/local/bin/gdm-wallpaper-update monitors "$f" || true
}

sync_settings
sync_monitors

KEYS=(
    "org.gnome.desktop.background picture-uri-dark"
    "org.gnome.desktop.background picture-uri"
    "org.gnome.desktop.background picture-options"
    "org.gnome.desktop.background primary-color"
    "org.gnome.desktop.background secondary-color"
    "org.gnome.desktop.interface color-scheme"
    "org.gnome.desktop.interface icon-theme"
    "org.gnome.desktop.interface cursor-theme"
    "org.gnome.desktop.interface cursor-size"
    "org.gnome.desktop.interface gtk-theme"
    "org.gnome.desktop.interface font-name"
    "org.gnome.desktop.interface document-font-name"
    "org.gnome.desktop.interface monospace-font-name"
    "org.gnome.desktop.interface text-scaling-factor"
    "org.gnome.desktop.interface clock-format"
    "org.gnome.desktop.interface clock-show-seconds"
    "org.gnome.desktop.interface clock-show-weekday"
    "org.gnome.desktop.peripherals.mouse speed"
    "org.gnome.desktop.peripherals.mouse natural-scroll"
    "org.gnome.desktop.peripherals.touchpad speed"
    "org.gnome.desktop.peripherals.touchpad tap-to-click"
    "org.gnome.desktop.peripherals.touchpad natural-scroll"
)

(
    for k in "${KEYS[@]}"; do
        gsettings monitor $k &
    done
    wait
) | while read -r _; do
    sync_settings
done &

if command -v inotifywait &>/dev/null; then
    while inotifywait -qq -e close_write -e moved_to "$HOME/.config/monitors.xml" 2>/dev/null; do
        sync_monitors
    done
fi

wait
