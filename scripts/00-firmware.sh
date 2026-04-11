#!/bin/bash
set -e
echo "=== Installing Zenbook S14 ISH firmware ==="
TMP=$(mktemp -d)
git clone --depth=1 https://github.com/dantmnf/zenbook-s14-linux.git "$TMP"
sudo install -Dm644 "$TMP/firmware/intel/ish/ish_lnlm_ef534c00_fb3b8d86.bin" \
    /lib/firmware/intel/ish/ish_lnlm_ef534c00_fb3b8d86.bin
rm -rf "$TMP"
