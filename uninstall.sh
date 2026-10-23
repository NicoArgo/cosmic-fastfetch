#!/usr/bin/env bash
# POP Flow — cosmic-fastfetch: take out what install.sh put in.
#
# Removes the ~/.bashrc block and the logo, and puts back the fastfetch config
# you had before (or none). fastfetch itself stays installed; to remove it too:
#   sudo apt remove fastfetch
set -euo pipefail

CONF_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch
CONF=$CONF_DIR/config.jsonc
BASHRC=$HOME/.bashrc
MARK_BEGIN="# >>> POP Flow: cosmic-fastfetch >>>"
MARK_END="# <<< POP Flow: cosmic-fastfetch <<<"

if [ -f "$BASHRC" ] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
    sed -i "\|^$MARK_BEGIN\$|,\|^$MARK_END\$|d" "$BASHRC"
    echo "==> New terminals no longer run fastfetch"
fi

rm -f "$CONF_DIR/pop-flow-logo.txt"
if [ -e "$CONF.pop-flow-orig" ]; then
    mv "$CONF.pop-flow-orig" "$CONF"
    echo "==> Your previous fastfetch config is back"
elif [ -f "$CONF" ] && grep -q 'POP Flow' "$CONF"; then
    rm "$CONF"
    echo "==> fastfetch back to its defaults"
fi
rmdir "$CONF_DIR" 2>/dev/null || true

echo "==> cosmic-fastfetch removed (fastfetch itself is still installed)"
