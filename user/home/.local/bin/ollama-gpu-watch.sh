#!/usr/bin/env bash
#
# ollama-gpu-watch — GPU offload spillover monitor with auto-recovery
#
# On this machine (Lunar Lake iGPU, shared LPDDR5X) a model that loaded at
# 100% GPU can later spill layers to the CPU as system memory fragments.
# Root cause is memory fragmentation, NOT model size — a clean page cache
# lets the same model reload fully on the GPU again.
#
# This service polls `ollama ps`; when a loaded model is no longer at
# "100% GPU" it runs `sudo llm-fresh` (drop_caches + ollama restart) to
# defragment memory and restore full GPU offload. A cooldown prevents a
# restart loop. Desktop notifications are sent on every spillover event.
#
# Requires: passwordless sudoers entry for /usr/local/bin/llm-fresh.

LOG="$HOME/.local/share/ollama-gpu-watch.log"
INTERVAL="${WATCH_INTERVAL:-30}"     # seconds between checks
COOLDOWN="${WATCH_COOLDOWN:-180}"    # min seconds between auto-fixes (loop guard)
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 1

log(){ echo "$(date '+%F %T') | $1" >> "$LOG" 2>/dev/null; }

# Send a desktop notification. The service runs under default.target, so it
# has to reach the user session bus explicitly.
notify(){
  local uid bus
  uid=$(id -u)
  bus="/run/user/$uid/bus"
  [ -S "$bus" ] || return 0
  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
    notify-send -a "Ollama GPU Watch" -u critical "$1" "$2" 2>/dev/null
  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
    canberra-gtk-play -i dialog-error 2>/dev/null &
}

last_fix=0
check_once(){
  command -v ollama >/dev/null 2>&1 || { log "ollama binary missing"; return 1; }
  ollama list >/dev/null 2>&1        || { log "ollama unreachable";    return 1; }

  local mem map
  mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2}'); [ -z "$mem" ] && mem="n/a"
  map=$(ollama ps 2>/dev/null | awk 'NR>1 && NF>0')
  [ -z "$map" ] && { log "no model loaded | RAM:$mem"; return 0; }

  echo "$map" | while read -r line; do
    # The SIZE field contains a space ("18 GB"), so parse relative to the
    # GPU token instead of relying on fixed column positions.
    parsed=$(echo "$line" | awk '{
      name=$1
      for(i=2;i<=NF;i++){ if($i=="GPU"||$i ~ /GPU$/){proc=$(i-1)" "$i; ctx=$(i+1); break} }
      print name"|"proc"|"ctx
    }')
    name=$(echo "$parsed" | cut -d'|' -f1)
    proc=$(echo "$parsed" | cut -d'|' -f2)
    ctx=$(echo  "$parsed" | cut -d'|' -f3)
    [ -z "$name" ] && continue
    log "$name | $proc | ctx:$ctx | RAM:$mem"

    if [ -n "$proc" ] && [ "$proc" != "100% GPU" ]; then
      now=$(date +%s)
      if [ $((now - last_fix)) -ge "$COOLDOWN" ]; then
        log "SPILLOVER: $name ($proc) -> auto-fix via llm-fresh"
        notify "GPU offload spillover — recovering" "$name is running on CPU ($proc). Defragmenting memory and reloading on GPU."
        sudo -n /usr/local/bin/llm-fresh >/dev/null 2>&1 \
          && log "auto-fix OK" \
          || log "auto-fix FAILED (check sudoers)"
        echo "$(date +%s)" > /tmp/.ollama-watch-lastfix
      else
        log "SPILLOVER: $name ($proc) - within cooldown, skipped"
        notify "GPU offload spillover" "$name is running on CPU ($proc). Auto-fix on cooldown."
      fi
    fi
  done
  # Carry the cooldown timestamp back out of the `while|read` subshell.
  [ -f /tmp/.ollama-watch-lastfix ] && last_fix=$(cat /tmp/.ollama-watch-lastfix 2>/dev/null)
}

log "=== watcher started (interval=${INTERVAL}s, cooldown=${COOLDOWN}s, auto-fix=ON) ==="
while true; do check_once; sleep "$INTERVAL"; done
