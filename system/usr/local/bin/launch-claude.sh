#!/bin/bash
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SCHEME=$(grep "^ColorScheme=" "$HOME/.config/kdedefaults/kdeglobals" 2>/dev/null | cut -d= -f2)
if echo "$SCHEME" | grep -qi "dark"; then
    COLOR="Breath"
else
    COLOR="BreathLight"
fi
kwriteconfig6 --file "$HOME/.local/share/konsole/Claude AI.profile" \
    --group Appearance --key ColorScheme "$COLOR"
konsole --workdir /home/dechros --title "Claude AI" --profile "Claude AI" \
    -e zsh -c "claude --dangerously-skip-permissions; exec zsh" &
KONSOLE_PID=$!
echo $KONSOLE_PID > /tmp/claude-ai-pid
touch /tmp/claude-ai-open
wait $KONSOLE_PID
rm -f /tmp/claude-ai-open /tmp/claude-ai-pid
