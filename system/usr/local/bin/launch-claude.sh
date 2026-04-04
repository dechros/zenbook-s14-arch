#!/bin/bash
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

kgx --title "Claude AI" --working-directory=/home/dechros \
    -e zsh -c "claude --dangerously-skip-permissions; exec zsh" &
TERM_PID=$!
echo $TERM_PID > /tmp/claude-ai-pid
touch /tmp/claude-ai-open
wait $TERM_PID
rm -f /tmp/claude-ai-open /tmp/claude-ai-pid
