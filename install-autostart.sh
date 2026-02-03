#!/bin/bash
# Install or uninstall Unsplash BG autostart at session login (Linux)

set -e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${ROOT_DIR}/change-wallpaper.sh"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/unsplash-bg.desktop"

if [[ "$1" == "--uninstall" ]] || [[ "$1" == "-u" ]]; then
	rm -f "$DESKTOP_FILE"
	echo "Autostart removed: $DESKTOP_FILE"
	exit 0
fi

mkdir -p "$AUTOSTART_DIR"
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=Unsplash Background
Comment=Set random Unsplash wallpaper on login
Exec=${SCRIPT_PATH}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
echo "Autostart installed: $DESKTOP_FILE"
echo "To remove: $0 --uninstall"
