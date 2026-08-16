#!/bin/bash
# Unsplash Background Changer - Linux
# Uses config.json (same format as Windows). Requires: curl, jq or python3.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="${ROOT_DIR}/config.json"

# Defaults (used if config missing or invalid)
ACCESS_KEY=""
API_URL="https://api.unsplash.com"
CATEGORY="nature"
WIDTH=1920
HEIGHT=1080
TEMP_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/UnsplashBG"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/unsplash-bg.log"
STYLE="fill"

log() {
	local msg="$1"
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S')
	echo "[$ts] $msg"
	mkdir -p "$LOG_DIR"
	echo "[$ts] $msg" >> "$LOG_FILE"
}

json_get_file() {
	local path="$1"
	local file="$2"
	if command -v jq &>/dev/null; then
		jq -r "$path" "$file" 2>/dev/null || echo ""
	elif command -v python3 &>/dev/null; then
		python3 - <<'PY' "$file" "$path"
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    for key in sys.argv[2].lstrip('.').split('.'):
        if isinstance(data, dict) and key:
            data = data.get(key, None)
        else:
            data = None
            break
    if data is None:
        print("")
    elif isinstance(data, bool):
        print(str(data).lower())
    else:
        print(data)
except Exception:
    print("")
PY
	else
		echo ""
	fi
}

json_get_stdin() {
	local path="$1"
	if command -v jq &>/dev/null; then
		jq -r "$path" 2>/dev/null || echo ""
	elif command -v python3 &>/dev/null; then
		python3 - <<'PY' "$path"
import json, sys
try:
    data = json.load(sys.stdin)
    for key in sys.argv[1].lstrip('.').split('.'):
        if isinstance(data, dict) and key:
            data = data.get(key, None)
        else:
            data = None
            break
    if data is None:
        print("")
    elif isinstance(data, bool):
        print(str(data).lower())
    else:
        print(data)
except Exception:
    print("")
PY
	else
		echo ""
	fi
}

# Load config if present
if [[ -f "$CONFIG_PATH" ]]; then
	ACCESS_KEY=$(json_get_file '.unsplash.accessKey' "$CONFIG_PATH")
	API_URL=$(json_get_file '.unsplash.apiUrl' "$CONFIG_PATH")
	CATEGORY=$(json_get_file '.unsplash.defaultCategory' "$CONFIG_PATH")
	WIDTH=$(json_get_file '.unsplash.defaultWidth' "$CONFIG_PATH")
	HEIGHT=$(json_get_file '.unsplash.defaultHeight' "$CONFIG_PATH")
	STYLE=$(json_get_file '.wallpaper.style' "$CONFIG_PATH")
	if path=$(json_get_file '.download.tempPath' "$CONFIG_PATH"); [[ -n "$path" && "$path" != "null" ]]; then
		# expand $HOME if present in config
		TEMP_PATH="${path//\$HOME/$HOME}"
		TEMP_PATH="${TEMP_PATH//\$\{HOME\}/$HOME}"
	fi
	logfile_cfg=$(json_get_file '.logging.logFile' "$CONFIG_PATH")
	if [[ -n "$logfile_cfg" && "$logfile_cfg" != "null" ]]; then
		logfile_cfg="${logfile_cfg//\\/\/}"
		LOG_FILE="${ROOT_DIR}/${logfile_cfg}"
		LOG_DIR="$(dirname "$LOG_FILE")"
	fi
	if [[ -z "$API_URL" ]]; then
		API_URL="https://api.unsplash.com"
	fi
	if [[ -z "$CATEGORY" ]]; then
		CATEGORY="nature"
	fi
	if [[ -z "$WIDTH" ]]; then
		WIDTH=1920
	fi
	if [[ -z "$HEIGHT" ]]; then
		HEIGHT=1080
	fi
	if [[ -z "$STYLE" ]]; then
		STYLE="fill"
	fi
	if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
		log "WARNING: jq and python3 are not installed. Using defaults. Install jq or python3 for config support."
	fi
else
	log "WARNING: config.json not found at $CONFIG_PATH. Using defaults."
fi
if [[ -z "$ACCESS_KEY" ]]; then
	log "ERROR: API key not configured. Create config.json from config.json.template and set unsplash.accessKey."
	exit 1
fi

mkdir -p "$TEMP_PATH"
FILE_NAME="unsplash_${WIDTH}x${HEIGHT}_$$.jpg"
FILE_PATH="${TEMP_PATH}/${FILE_NAME}"

# Fetch random image URL from Unsplash API
log "Requesting random image: category=$CATEGORY, ${WIDTH}x${HEIGHT}"
url="${API_URL}/photos/random?query=${CATEGORY}&orientation=landscape&w=${WIDTH}&h=${HEIGHT}"
resp=$(curl -sS -H "Authorization: Client-ID ${ACCESS_KEY}" -H "Accept-Version: v1" "$url") || true

image_url=$(echo "$resp" | json_get_stdin '.urls.raw')
if [[ -z "$image_url" ]]; then
	log "ERROR: Invalid API response. Check key and network."
	echo "$resp"
	exit 1
fi

img_id=$(echo "$resp" | json_get_stdin '.id')
if [[ -z "$img_id" ]]; then
	img_id="unknown"
fi
log "Downloading image id=$img_id"

if ! curl -sS -o "$FILE_PATH" "$image_url"; then
	log "ERROR: Download failed"
	exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
	log "ERROR: File not saved"
	exit 1
fi

log "Image saved: $FILE_PATH"

# Set wallpaper by desktop environment
set_wallpaper() {
	local img="$1"
	local style="${2:-fill}"
	# absolute path for URI
	local abs
	abs="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"

	if [[ -n "$SWAYSOCK" ]]; then
		# Sway
		swaymsg "output * bg $abs $style" 2>/dev/null && { log "Wallpaper set (Sway)"; return 0; }
	fi

	if [[ -n "$WAYLAND_DISPLAY" ]] && command -v gsettings &>/dev/null; then
		# GNOME on Wayland (set both so light/dark theme both update)
		gsettings set org.gnome.desktop.background picture-uri "file://$abs"
		gsettings set org.gnome.desktop.background picture-uri-dark "file://$abs"
		log "Wallpaper set (GNOME Wayland)"
		return 0
	fi

	if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
		case "$XDG_CURRENT_DESKTOP" in
			*[Gg]nome*)
				gsettings set org.gnome.desktop.background picture-uri "file://$abs"
				gsettings set org.gnome.desktop.background picture-uri-dark "file://$abs"
				log "Wallpaper set (GNOME)"
				return 0
				;;
			*[Kk][Dd][Ee]*|*Plasma*)
				if command -v qdbus &>/dev/null; then
					local fillMode
					case "$style" in
						fill) fillMode=2 ;;    # Keep Proportions Crop
						fit) fillMode=1 ;;     # Keep Proportions
						stretch) fillMode=0 ;;  # Stretch
						center) fillMode=4 ;;   # Centered
						tile) fillMode=3 ;;     # Tile
						*) fillMode=2 ;;
					esac
					qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "var allDesktops = desktops(); for (var i = 0; i < allDesktops.length; i++) { var d = allDesktops[i]; d.wallpaperPlugin = 'org.kde.image'; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$abs'); d.writeConfig('FillMode', $fillMode); }" 2>/dev/null && { log "Wallpaper set (Plasma 5/6)"; return 0; }
				fi
				if command -v kwriteconfig6 &>/dev/null; then
					kwriteconfig6 --file kwinrc --group org.kde.kwin.screensaver --key Image "file://$abs" 2>/dev/null
					qdbus org.kde.KWin /KWin reconfigure 2>/dev/null
					log "Wallpaper set (KDE)"
					return 0
				fi
				# Plasma 5 wallpaper plugin
				plasma-apply-wallpaperimage "$abs" 2>/dev/null && { log "Wallpaper set (Plasma)"; return 0; }
				;;
			*[Xx][Ff][Cc][Ee]*)
				xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$abs" 2>/dev/null && { log "Wallpaper set (XFCE)"; return 0; }
				;;
		esac
	fi

	# Fallback: feh (works on many WMs: i3, bspwm, etc.)
	if command -v feh &>/dev/null; then
		case "$style" in
			fill|stretch) feh --bg-fill "$abs" ;;
			fit)          feh --bg-scale "$abs" ;;
			center)       feh --bg-center "$abs" ;;
			tile)         feh --bg-tile "$abs" ;;
			*)            feh --bg-fill "$abs" ;;
		esac
		log "Wallpaper set (feh)"
		return 0
	fi

	# Fallback: nitrogen
	if command -v nitrogen &>/dev/null; then
		nitrogen --set-zoom-fill "$abs" 2>/dev/null && { log "Wallpaper set (nitrogen)"; return 0; }
	fi

	log "ERROR: No supported wallpaper setter found. Install feh, or use GNOME/KDE/XFCE."
	return 1
}

if set_wallpaper "$FILE_PATH" "$STYLE"; then
	log "Done."
else
	exit 1
fi
