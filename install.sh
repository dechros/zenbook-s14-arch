#!/bin/bash
set -e

export REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    echo "Run as normal user, not root."
    exit 1
fi

for phase in "$REPO_DIR/scripts/"*.sh; do
    echo
    echo "### Running $(basename "$phase") ###"
    bash "$phase"
done

echo
echo "=== Done. Reboot recommended. ==="
