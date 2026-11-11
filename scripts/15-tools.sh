#!/bin/bash
set -e

# Development, embedded, networking and security tooling.
echo "=== Installing tools (pacman) ==="
sudo pacman -S --needed --noconfirm \
    aircrack-ng alsa-utils android-tools android-udev arduino-cli ark \
    arp-scan bettercap binwalk bully bun cmake cowpatty deno dialog dolphin \
    dsniff esptool ettercap expect exploitdb freerdp ghidra git-filter-repo \
    git-lfs gobuster gradle hashcat hashcat-utils hcxdumptool hcxtools \
    help2man hostapd hping hydra icoutils imagemagick impacket \
    john kismet konsole lftp lib32-pipewire-jack \
    ltrace macchanger masscan maven mdk4 medusa metasploit mitmproxy \
    moreutils ncrack netsniff-ng ngrep nikto nodejs npm openbsd-netcat \
    parallel perl-image-exiftool perl-net-dns perl-net-ip perl-xml-writer \
    php picocom pixiewps platformio-core platformio-core-udev \
    proxychains-ng python-paramiko python-pip python-pipx radare2 reaver \
    remmina rustscan samba scrcpy sqlmap squashfs-tools sslscan sslsplit \
    strace tcc tcpdump tcpflow unixodbc valgrind vim wifite wireless_tools \
    wireshark-qt xmlstarlet yara yq zaproxy

echo "=== Installing tools (AUR via yay) ==="
yay -S --needed --noconfirm \
    amass btscanner burpsuite chisel-bin commix dirb dnsx enum4linux-ng \
    feroxbuster ffuf hostapd-wpe httpx jwt_tool kerbrute-bin ligolo-ng \
    netexec nuclei perl-net-netmask perl-string-random responder seclists \
    sslyze steghide subfinder wafw00f wfuzz whatweb
