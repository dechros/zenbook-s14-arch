#!/bin/bash
set -e
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# AppGrid launcher customization (dechros): clean grid — no search bar, no
# category bar, no dividers/border, no top header gap, typing doesn't trigger
# search. We don't fork or vendor the (GPL, ~100-file C++/QML) plugin; instead
# we copy the installed system plasmoid into the user override dir and apply
# small patches. The user copy (~/.local) shadows /usr/share, so it survives
# package updates and is reverted by simply deleting the override dir.

SYS=/usr/share/plasma/plasmoids/dev.xarbit.appgrid
LOC="$HOME/.local/share/plasma/plasmoids/dev.xarbit.appgrid"

if [[ ! -d "$SYS" ]]; then
    echo "=== AppGrid not installed (plasma6-applets-appgrid), skipping ==="
    exit 0
fi

echo "=== Deploying AppGrid customization to user override ==="
rm -rf "$LOC"
mkdir -p "$(dirname "$LOC")"
cp -r "$SYS" "$LOC"

for f in GridPanel.qml AppGridView.qml; do
    if patch -s "$LOC/contents/ui/$f" < "$REPO_DIR/appgrid/$f.patch"; then
        echo "  patched $f"
    else
        echo "  WARN: $f patch failed — upstream likely changed; re-create the patch."
    fi
done

# Drop stale compiled QML so the override is picked up on next plasmashell start.
rm -rf "$HOME/.cache/plasmashell/qmlcache" 2>/dev/null || true
echo "=== Done. Log out/in or restart plasmashell to apply. ==="
