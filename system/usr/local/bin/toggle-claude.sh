#!/bin/bash
PID=$(cat /tmp/claude-ai-pid 2>/dev/null)
[[ -z "$PID" ]] && exit 0
SCRIPT=$(mktemp /tmp/kwin-XXXXXX.js)
cat > "$SCRIPT" << KWINSCRIPT
var clients = workspace.windowList();
for (var i = 0; i < clients.length; i++) {
    if (clients[i].pid === ${PID}) {
        if (clients[i].minimized) {
            clients[i].minimized = false;
            workspace.activeWindow = clients[i];
        } else if (workspace.activeWindow === clients[i]) {
            clients[i].minimized = true;
        } else {
            workspace.activeWindow = clients[i];
        }
        break;
    }
}
KWINSCRIPT
ID=$(DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SCRIPT" 2>/dev/null)
if [[ -n "$ID" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" qdbus6 org.kde.KWin "/Scripting/Script${ID}" org.kde.kwin.Script.run 2>/dev/null
    sleep 0.2
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT" 2>/dev/null
fi
rm -f "$SCRIPT"
