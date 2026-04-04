#!/bin/bash
PID=$(cat /tmp/claude-ai-pid 2>/dev/null)
[[ -z "$PID" ]] && exit 0

DBUS_ADDR="unix:path=/run/user/$(id -u)/bus"

DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval "
        let start = global.get_current_time();
        let wins = global.get_window_actors()
            .map(a => a.meta_window)
            .filter(w => w.get_pid() === ${PID});
        if (wins.length > 0) {
            let w = wins[0];
            if (w.minimized) {
                w.unminimize();
                w.activate(start);
            } else if (w.has_focus()) {
                w.minimize();
            } else {
                w.activate(start);
            }
        }
    " 2>/dev/null
