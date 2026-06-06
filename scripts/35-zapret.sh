#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# DPI bypass for Turkish ISP (Türkcell Superonline) blocking Discord, etc.
# - zapret-git from AUR (nfqws DPI desync)
# - Cloudflare DNS to defeat ISP DNS hijacking
# - working NFQWS strategy for Superonline: fakedsplit + md5sig fooling

echo "=== Installing zapret-git (AUR) ==="
if ! pacman -Q zapret-git &>/dev/null && ! pacman -Q zapret &>/dev/null; then
    yay -S --needed --noconfirm zapret-git
fi

echo "=== Installing zapret config (Superonline Discord bypass) ==="
sudo install -d /opt/zapret
sudo install -m 644 "$REPO_DIR/system/opt/zapret/config" /opt/zapret/config

echo "=== Enabling zapret service ==="
sudo systemctl enable --now zapret
sudo systemctl restart zapret

echo "=== Setting Cloudflare DNS to defeat ISP DNS hijacking ==="
# NOTE: the primary, permanent mechanism is the global NetworkManager DNS at
# system/etc/NetworkManager/conf.d/dns-cloudflare.conf (deployed by 20-system.sh),
# which forces Cloudflare DNS on EVERY network automatically. The per-connection
# nmcli below is a belt-and-suspenders fallback for the currently-active Wi-Fi.
CONN="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
    | grep -iE ':(802-11-wireless|wifi)$' | head -1 | cut -d: -f1)"
if [[ -n "$CONN" ]]; then
    nmcli connection modify "$CONN" \
        ipv4.dns "1.1.1.1,1.0.0.1" ipv4.ignore-auto-dns yes \
        ipv6.dns "2606:4700:4700::1111,2606:4700:4700::1001" ipv6.ignore-auto-dns yes
    nmcli connection up "$CONN" || true
    echo "DNS set on '$CONN'"
else
    echo "No active Wi-Fi connection found; set Cloudflare DNS manually."
fi

echo "=== Verifying Discord reachability ==="
for u in discord.com gateway.discord.gg; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "https://$u" || echo "000")
    echo "  $u -> $code"
done
