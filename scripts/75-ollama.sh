#!/bin/bash
set -e

echo "=== Ollama local AI setup (Lunar Lake iGPU) ==="

# --- packages: ollama-vulkan + opencode (no model pull; user pulls later) ---
NEED=()
pacman -Q ollama-vulkan &>/dev/null || NEED+=(ollama-vulkan)
pacman -Q opencode      &>/dev/null || NEED+=(opencode)
pacman -Q wl-clipboard  &>/dev/null || NEED+=(wl-clipboard)
if [[ ${#NEED[@]} -gt 0 ]]; then
    sudo pacman -S --needed --noconfirm "${NEED[@]}"
fi

# --- ollama runtime drop-ins (iGPU enable, 64K context, OOM priority) ---
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/system/ollama.service.d/igpu.conf" \
    /etc/systemd/system/ollama.service.d/igpu.conf
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/system/ollama.service.d/oom.conf" \
    /etc/systemd/system/ollama.service.d/oom.conf
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/system/ollama.service.d/kv.conf" \
    /etc/systemd/system/ollama.service.d/kv.conf
sudo install -Dm644 "$REPO_DIR/system/etc/systemd/system/ollama.service.d/vram.conf" \
    /etc/systemd/system/ollama.service.d/vram.conf

# iGPU memory ceiling. Needs the module reloaded, so it applies from the next boot.
sudo install -Dm644 "$REPO_DIR/system/etc/modprobe.d/ttm.conf" /etc/modprobe.d/ttm.conf

# --- llm-fresh helper (clean-memory restart) ---
sudo install -Dm755 "$REPO_DIR/system/usr/local/bin/llm-fresh" /usr/local/bin/llm-fresh

# --- passwordless sudoers so the watcher can auto-fix spillover ---
echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/llm-fresh" | \
    sudo tee /etc/sudoers.d/llm-fresh >/dev/null
sudo chmod 440 /etc/sudoers.d/llm-fresh
sudo visudo -c -f /etc/sudoers.d/llm-fresh >/dev/null

# --- sleep hook: unload model before hibernate, restart after resume ---
sudo install -Dm755 "$REPO_DIR/system/usr/lib/systemd/system-sleep/ollama" \
    /usr/lib/systemd/system-sleep/ollama

# --- add user to render/video for iGPU access ---
sudo usermod -aG render,video "$USER"

# --- enable ollama service (starts, but NO model is pulled) ---
sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service

# --- sampling-parameter proxy: injects SYSTEM_PROMPT.txt and sampling settings
# --- in front of ollama /v1 on port 11435, which is what opencode talks to ---
install -Dm644 "$REPO_DIR/user/.local/share/local-llm/SYSTEM_PROMPT.txt" \
    "$HOME/.local/share/local-llm/SYSTEM_PROMPT.txt"
install -Dm644 "$REPO_DIR/user/.local/share/local-llm/qwen36-35b-a3b.modelfile" \
    "$HOME/.local/share/local-llm/qwen36-35b-a3b.modelfile"
install -Dm755 "$REPO_DIR/user/.local/share/local-llm/param-proxy.py" \
    "$HOME/.local/share/local-llm/param-proxy.py"
install -Dm644 "$REPO_DIR/user/.config/systemd/user/ollama-param-proxy.service" \
    "$HOME/.config/systemd/user/ollama-param-proxy.service"
systemctl --user daemon-reload
systemctl --user enable --now ollama-param-proxy.service

# --- GPU spillover watcher (auto-fixes via llm-fresh) ---
install -Dm755 "$REPO_DIR/user/home/.local/bin/ollama-gpu-watch.sh" \
    "$HOME/.local/bin/ollama-gpu-watch.sh"
install -Dm644 "$REPO_DIR/user/home/.config/systemd/user/ollama-gpu-watch.service" \
    "$HOME/.config/systemd/user/ollama-gpu-watch.service"
systemctl --user daemon-reload
systemctl --user enable --now ollama-gpu-watch.service

echo "=== Ollama ready. Pull a model yourself, e.g.:"
echo "===   ollama pull huihui_ai/qwen3.5-abliterated:9b"
echo "=== (no model was pulled automatically) ==="
