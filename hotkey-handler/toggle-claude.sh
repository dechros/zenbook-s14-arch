#!/bin/bash
LOCKFILE="/tmp/toggle-claude.lock"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

PIDFILE="/tmp/claude-ai-pid"

if [[ ! -f "$PIDFILE" ]] || ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    setsid /usr/local/bin/launch-claude.sh 9>&- </dev/null >/dev/null 2>&1 &
    disown
    exit 0
fi

PID=$(cat "$PIDFILE")
SCRIPT=$(mktemp --suffix=.js)
cat > "$SCRIPT" <<JS
const targetPid = $PID;
const windows = workspace.windowList();
for (const w of windows) {
    if (w.pid === targetPid) {
        if (w.minimized) {
            w.minimized = false;
            workspace.activeWindow = w;
        } else if (workspace.activeWindow === w) {
            w.minimized = true;
        } else {
            workspace.activeWindow = w;
        }
        break;
    }
}
JS

ID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SCRIPT" 2>/dev/null)
if [[ -n "$ID" ]]; then
    qdbus6 org.kde.KWin "/Scripting/Script$ID" org.kde.kwin.Script.run 2>/dev/null
    qdbus6 org.kde.KWin "/Scripting/Script$ID" org.kde.kwin.Script.stop 2>/dev/null
fi
rm -f "$SCRIPT"
