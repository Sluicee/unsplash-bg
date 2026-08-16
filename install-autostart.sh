#!/bin/bash
# Install or uninstall Unsplash BG autostart at session login (Linux)

set -eo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${ROOT_DIR}/change-wallpaper.sh"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/unsplash-bg.desktop"

if [[ "$1" == "--uninstall" ]] || [[ "$1" == "-u" ]]; then
	rm -f "$DESKTOP_FILE"
	echo "Autostart removed: $DESKTOP_FILE"
	exit 0
fi

if [[ ! -f "$SCRIPT_PATH" ]]; then
	echo "ERROR: $SCRIPT_PATH not found." >&2
	exit 1
fi

# Wait before running: Plasma's D-Bus interface (and GNOME's session bus) is not
# ready the instant autostart fires, so an immediate run silently does nothing.
DELAY="${UNSPLASH_BG_DELAY:-5}"

mkdir -p "$AUTOSTART_DIR"
# Exec runs through bash with a quoted path: the project directory may contain
# spaces, and a cloned change-wallpaper.sh may lack the executable bit.
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Unsplash Background
Comment=Set random Unsplash wallpaper on login
Exec=/bin/bash -c "sleep ${DELAY}; exec '${SCRIPT_PATH}'"
Path=${ROOT_DIR}
Terminal=false
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
EOF
echo "Autostart installed: $DESKTOP_FILE"
echo "  runs: $SCRIPT_PATH (after ${DELAY}s delay)"
echo "To change the delay: UNSPLASH_BG_DELAY=15 $0"
echo "To remove: $0 --uninstall"
