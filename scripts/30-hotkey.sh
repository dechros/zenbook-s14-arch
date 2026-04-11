#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
echo "=== Installing hotkey handler ==="
"$REPO_DIR/hotkey-handler/install.sh"
