#!/usr/bin/env bash
# ollama-gpu-watch: GPU/CPU spillover izler ve OTOMATIK duzeltir.
# Spillover sebebi bellek kirliligi (olculdu); model buyuklugu degil.
# Cozum: spillover gorununce `sudo llm-fresh` (drop_caches + ollama restart).
LOG="$HOME/.local/share/ollama-gpu-watch.log"
INTERVAL="${WATCH_INTERVAL:-30}"
COOLDOWN="${WATCH_COOLDOWN:-180}"   # ayni modeli 3 dk icinde tekrar duzeltme (dongu onleme)
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 1

log(){ echo "$(date '+%F %T') | $1" >> "$LOG" 2>/dev/null; }

# masaustu bildirimi icin oturum ortamini bul (servis default.target'ta calisir)
notify(){
  local uid; uid=$(id -u)
  local bus="/run/user/$uid/bus"
  [ -S "$bus" ] || return 0
  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" notify-send -a "Ollama" -u critical "$1" "$2" 2>/dev/null
  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" canberra-gtk-play -i dialog-error 2>/dev/null &
}

last_fix=0
check_once(){
  command -v ollama >/dev/null 2>&1 || { log "ollama binary missing"; return 1; }
  ollama list >/dev/null 2>&1 || { log "ollama unreachable"; return 1; }
  local mem; mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2}'); [ -z "$mem" ] && mem="n/a"
  local map; map=$(ollama ps 2>/dev/null | awk 'NR>1 && NF>0')
  [ -z "$map" ] && { log "no model loaded | RAM:$mem"; return 0; }

  echo "$map" | while read -r line; do
    parsed=$(echo "$line" | awk '{name=$1; for(i=2;i<=NF;i++){if($i=="GPU"||$i ~ /GPU$/){proc=$(i-1)" "$i; ctx=$(i+1); break}} print name"|"proc"|"ctx}')
    name=$(echo "$parsed" | cut -d'|' -f1); proc=$(echo "$parsed" | cut -d'|' -f2); ctx=$(echo "$parsed" | cut -d'|' -f3)
    [ -z "$name" ] && continue
    log "$name | $proc | ctx:$ctx | RAM:$mem"
    if [ -n "$proc" ] && [ "$proc" != "100% GPU" ]; then
      now=$(date +%s)
      if [ $((now - last_fix)) -ge "$COOLDOWN" ]; then
        log "SPILLOVER: $name ($proc) -> auto-fix: llm-fresh"
        notify "GPU spillover - duzeltiliyor" "$name $proc"
        sudo -n /usr/local/bin/llm-fresh >/dev/null 2>&1 && log "auto-fix OK" || log "auto-fix FAILED (sudoers?)"
        echo "$(date +%s)" > /tmp/.ollama-watch-lastfix
      else
        log "SPILLOVER: $name ($proc) - cooldown aktif, atlandi"
        notify "GPU spillover" "$name $proc (cooldown)"
      fi
    fi
  done
  # cooldown'u alt-shell disina tasi (while|read subshell sorunu)
  [ -f /tmp/.ollama-watch-lastfix ] && last_fix=$(cat /tmp/.ollama-watch-lastfix 2>/dev/null)
}

log "=== watcher basladi (interval=${INTERVAL}s, cooldown=${COOLDOWN}s, auto-fix=ON) ==="
while true; do check_once; sleep "$INTERVAL"; done
