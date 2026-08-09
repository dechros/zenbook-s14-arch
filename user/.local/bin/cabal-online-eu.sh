#!/bin/sh
export WINEPREFIX="$HOME/Games/cabal-online"
export WINEARCH=win64
export WINEDEBUG=-all
cd "$WINEPREFIX/drive_c/Program Files (x86)/CABAL Online (EU)" || exit 1
exec wine ./cabal.exe "$@"
