#!/usr/bin/env bash
# POP Flow — cosmic-fastfetch: fastfetch in every new terminal, optionally with
# your own logo drawn in letters and digits.
#
#   ./install.sh                         # fastfetch with the distro logo
#   ./install.sh --logo LOGO.png         # your logo, made of letters
#   ./install.sh --logo L --fill TEXT    # solid areas spell TEXT
#   ./install.sh --no-autostart          # don't run it in new terminals
#
# Logo options (passed on to tools/make-logo.py): --cols N, --crop X,Y,W,H,
# --circle, --invert, --by-light, --overlay FILE. A logo on a transparent
# background is drawn by its silhouette; otherwise light parts become letters.
#
# 1. Installs fastfetch if missing: from APT when the release has it, else the
#    .deb from fastfetch's GitHub releases (Pop!_OS 24.04 has no package).
# 2. Writes ~/.config/fastfetch/config.jsonc (a config that was already there
#    is kept as config.jsonc.pop-flow-orig) and the logo next to it.
# 3. Adds a marked block to ~/.bashrc that runs fastfetch in new interactive
#    terminals (not in scripts or nested shells).
#
# All per user; only installing fastfetch itself asks for sudo. Re-run it to
# change the logo, or after changing the terminal font (the logo is drawn for
# the cell size). ./uninstall.sh reverts 2 and 3 and leaves fastfetch installed.
set -euo pipefail
cd "$(dirname "$0")"

CONF_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch
CONF=$CONF_DIR/config.jsonc
LOGO=$CONF_DIR/pop-flow-logo.txt
BASHRC=$HOME/.bashrc
MARK_BEGIN="# >>> POP Flow: cosmic-fastfetch >>>"
MARK_END="# <<< POP Flow: cosmic-fastfetch <<<"

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

logo="" autostart=1 logo_args=()
while [ $# -gt 0 ]; do
    case $1 in
        --logo) logo=${2:?--logo needs a file}; shift 2 ;;
        --fill|--cols|--crop|--overlay)
            logo_args+=("$1" "${2:?$1 needs a value}"); shift 2 ;;
        --circle|--invert|--by-light) logo_args+=("$1"); shift ;;
        --no-autostart) autostart=0; shift ;;
        -h|--help) usage ;;
        *) echo "!! unknown option: $1"; usage 1 ;;
    esac
done
if [ "${#logo_args[@]}" -gt 0 ] && [ -z "$logo" ]; then
    echo "!! ${logo_args[0]} only makes sense with --logo"; exit 1
fi
if [ "$EUID" = 0 ]; then
    echo "!! run it as your user (it writes your config); it asks for sudo itself."
    exit 1
fi

# --- 1. fastfetch -----------------------------------------------------------------
if command -v fastfetch >/dev/null; then
    echo "==> fastfetch $(fastfetch --version | awk '{print $2}') already installed"
elif apt-cache policy fastfetch 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    echo "==> Installing fastfetch from APT"
    sudo apt-get install -y fastfetch
else
    case $(dpkg --print-architecture) in
        amd64) arch=amd64 ;;
        arm64) arch=aarch64 ;;
        *) echo "!! no fastfetch .deb for $(dpkg --print-architecture)"; exit 1 ;;
    esac
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    url=https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$arch.deb
    echo "==> fastfetch is not in APT here; downloading $url"
    curl -fL --progress-bar -o "$tmp/fastfetch.deb" "$url"
    # A path, not a name: apt installs the file and its dependencies.
    sudo apt-get install -y "$tmp/fastfetch.deb"
    echo "    (installed from a .deb: APT won't update it; re-run this to get a newer one"
    echo "     after removing it with: sudo apt remove fastfetch)"
fi

# --- 2. Config and logo -------------------------------------------------------------
mkdir -p "$CONF_DIR"
if [ -f "$CONF" ] && ! grep -q 'POP Flow' "$CONF" && [ ! -e "$CONF.pop-flow-orig" ]; then
    cp -a "$CONF" "$CONF.pop-flow-orig"
    echo "==> Your fastfetch config was kept as $CONF.pop-flow-orig"
fi

logo_block=""
if [ -n "$logo" ]; then
    [ -f "$logo" ] || { echo "!! no such file: $logo"; exit 1; }
    python3 -c 'import PIL' 2>/dev/null || {
        echo "==> Installing python3-pil (draws the logo)"
        sudo apt-get install -y python3-pil
    }
    python3 tools/make-logo.py "$logo" "${logo_args[@]}" > "$LOGO.new"
    mv "$LOGO.new" "$LOGO"
    echo "==> Logo drawn in $LOGO"
    logo_block=$(cat <<EOF
  "logo": {
    "type": "file",
    "source": "$LOGO",
    "color": { "1": "white" },
    "padding": { "left": 2, "right": 3 }
  },
EOF
)
else
    rm -f "$LOGO"
fi

# The module list has to be spelled out: a config without one prints only the logo.
cat > "$CONF" <<EOF
// POP Flow — cosmic-fastfetch. Written by install.sh; re-run it to change
// the logo (hand edits here are overwritten). ./uninstall.sh puts back the
// config you had before, if any.
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
$logo_block
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages",
    "shell", "display", "de", "wm", "terminal", "cpu", "gpu", "memory",
    "swap", "disk", "localip", "battery", "locale", "break", "colors"
  ]
}
EOF

# --- 3. New terminals ---------------------------------------------------------------
# Drop an old block first, so re-running never stacks two.
if [ -f "$BASHRC" ] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
    sed -i "\|^$MARK_BEGIN\$|,\|^$MARK_END\$|d" "$BASHRC"
fi
if [ "$autostart" = 1 ]; then
    cat >> "$BASHRC" <<EOF
$MARK_BEGIN
# Only in interactive top-level shells: not in scripts, not in nested bash.
if [[ \$- == *i* && \$SHLVL -le 1 ]] && command -v fastfetch >/dev/null; then
    fastfetch
fi
$MARK_END
EOF
    echo "==> New terminals open with fastfetch (block in $BASHRC)"
fi

echo "==> Done. Open a new terminal, or run: fastfetch"
