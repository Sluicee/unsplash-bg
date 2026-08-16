#!/bin/bash
# Unsplash Background Changer - Linux
# Uses config.json (same format as Windows). Requires: curl, jq or python3.

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_PATH="${ROOT_DIR}/config.json"

# Defaults (used if config missing or invalid)
ACCESS_KEY=""
API_URL="https://api.unsplash.com"
CATEGORY="nature"
WIDTH=1920
HEIGHT=1080
DEFAULT_TEMP_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/UnsplashBG"
TEMP_PATH="$DEFAULT_TEMP_PATH"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/unsplash-bg.log"
STYLE="fill"
KEEP_IMAGES="false"
MAX_CACHE_SIZE=10

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
		jq -r "$path // empty" "$file" 2>/dev/null || echo ""
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
		jq -r "$path // empty" 2>/dev/null || echo ""
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

is_positive_int() {
	[[ "$1" =~ ^[1-9][0-9]*$ ]]
}

# Load config if present
if [[ -f "$CONFIG_PATH" ]]; then
	ACCESS_KEY=$(json_get_file '.unsplash.accessKey' "$CONFIG_PATH")
	API_URL=$(json_get_file '.unsplash.apiUrl' "$CONFIG_PATH")
	CATEGORY=$(json_get_file '.unsplash.defaultCategory' "$CONFIG_PATH")
	WIDTH=$(json_get_file '.unsplash.defaultWidth' "$CONFIG_PATH")
	HEIGHT=$(json_get_file '.unsplash.defaultHeight' "$CONFIG_PATH")
	STYLE=$(json_get_file '.wallpaper.style' "$CONFIG_PATH")
	KEEP_IMAGES=$(json_get_file '.download.keepImages' "$CONFIG_PATH")
	MAX_CACHE_SIZE=$(json_get_file '.download.maxCacheSize' "$CONFIG_PATH")
	path=$(json_get_file '.download.tempPath' "$CONFIG_PATH")
	if [[ -n "$path" ]]; then
		# The shared template ships a Windows path ($env:TEMP\UnsplashBG) - ignore it here,
		# otherwise mkdir would create a literal directory with that name.
		if [[ "$path" == *'$env:'* || "$path" == *'%'* || "$path" == *'\'* ]]; then
			TEMP_PATH="$DEFAULT_TEMP_PATH"
		else
			TEMP_PATH="${path//\$\{HOME\}/$HOME}"
			TEMP_PATH="${TEMP_PATH//\$HOME/$HOME}"
			TEMP_PATH="${TEMP_PATH/#\~/$HOME}"
		fi
	fi
	logfile_cfg=$(json_get_file '.logging.logFile' "$CONFIG_PATH")
	if [[ -n "$logfile_cfg" ]]; then
		logfile_cfg="${logfile_cfg//\\//}"
		# Relative paths are resolved against the project root, not the current directory
		if [[ "$logfile_cfg" == /* ]]; then
			LOG_FILE="$logfile_cfg"
		else
			LOG_FILE="${ROOT_DIR}/${logfile_cfg}"
		fi
		LOG_DIR="$(dirname "$LOG_FILE")"
	fi
	[[ -n "$API_URL" ]] || API_URL="https://api.unsplash.com"
	[[ -n "$CATEGORY" ]] || CATEGORY="nature"
	is_positive_int "$WIDTH" || WIDTH=1920
	is_positive_int "$HEIGHT" || HEIGHT=1080
	[[ -n "$STYLE" ]] || STYLE="fill"
	[[ "$KEEP_IMAGES" == "true" ]] || KEEP_IMAGES="false"
	is_positive_int "$MAX_CACHE_SIZE" || MAX_CACHE_SIZE=10
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

if ! command -v curl &>/dev/null; then
	log "ERROR: curl is required but not installed."
	exit 1
fi

mkdir -p "$TEMP_PATH"
FILE_NAME="unsplash_${WIDTH}x${HEIGHT}_$$.jpg"
FILE_PATH="${TEMP_PATH}/${FILE_NAME}"

# Fetch random image URL from Unsplash API
log "Requesting random image: category=$CATEGORY, ${WIDTH}x${HEIGHT}"
url="${API_URL}/photos/random?query=${CATEGORY}&orientation=landscape"
resp=$(curl -sS -H "Authorization: Client-ID ${ACCESS_KEY}" -H "Accept-Version: v1" "$url") || true

raw_url=$(echo "$resp" | json_get_stdin '.urls.raw')
if [[ -z "$raw_url" ]]; then
	log "ERROR: Invalid API response. Check key and network."
	echo "$resp"
	exit 1
fi

# urls.raw is the full-size original; imgix parameters do the actual resizing
image_url="${raw_url}&w=${WIDTH}&h=${HEIGHT}&fit=crop&fm=jpg&q=85"

img_id=$(echo "$resp" | json_get_stdin '.id')
[[ -n "$img_id" ]] || img_id="unknown"
author=$(echo "$resp" | json_get_stdin '.user.name')
[[ -n "$author" ]] || author="unknown"
log "Downloading image id=$img_id by $author"

if ! curl -sSfL -o "$FILE_PATH" "$image_url"; then
	log "ERROR: Download failed"
	rm -f "$FILE_PATH"
	exit 1
fi

if [[ ! -s "$FILE_PATH" ]]; then
	log "ERROR: File not saved"
	rm -f "$FILE_PATH"
	exit 1
fi

log "Image saved: $FILE_PATH"

# Drop old cached images. The current wallpaper file must stay on disk:
# desktop environments reference it by path.
cleanup_cache() {
	local keep=1
	[[ "$KEEP_IMAGES" == "true" ]] && keep="$MAX_CACHE_SIZE"
	local old
	while IFS= read -r old; do
		[[ "$old" == "$FILE_PATH" ]] && continue
		rm -f "$old"
	done < <(find "$TEMP_PATH" -maxdepth 1 -type f -name 'unsplash_*.jpg' -printf '%T@ %p\n' 2>/dev/null \
		| sort -rn | tail -n +$((keep + 1)) | cut -d' ' -f2-)
}
cleanup_cache

# Resolve a Qt D-Bus client: Plasma 6 ships qdbus6/qdbus-qt6, Plasma 5 ships qdbus
find_qdbus() {
	local c
	for c in qdbus6 qdbus-qt6 qdbus; do
		if command -v "$c" &>/dev/null; then
			echo "$c"
			return 0
		fi
	done
	return 1
}

set_wallpaper_gnome() {
	local abs="$1" style="$2"
	local option
	case "$style" in
		fill) option="zoom" ;;
		fit) option="scaled" ;;
		stretch) option="stretched" ;;
		center) option="centered" ;;
		tile) option="wallpaper" ;;
		*) option="zoom" ;;
	esac
	gsettings set org.gnome.desktop.background picture-uri "file://$abs" || return 1
	# picture-uri-dark only exists on GNOME 42+; ignore failures on older versions
	gsettings set org.gnome.desktop.background picture-uri-dark "file://$abs" 2>/dev/null || true
	gsettings set org.gnome.desktop.background picture-options "$option" 2>/dev/null || true
	return 0
}

set_wallpaper_plasma() {
	local abs="$1" style="$2"
	local fillMode qdbus_bin
	case "$style" in
		fill) fillMode=2 ;;     # Keep Proportions Crop
		fit) fillMode=1 ;;      # Keep Proportions
		stretch) fillMode=0 ;;  # Stretch
		center) fillMode=6 ;;   # Centered
		tile) fillMode=3 ;;     # Tiled
		*) fillMode=2 ;;
	esac
	# Preferred: D-Bus script, the only way that also applies the fill mode
	if qdbus_bin=$(find_qdbus); then
		if "$qdbus_bin" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
			"var allDesktops = desktops(); for (var i = 0; i < allDesktops.length; i++) { var d = allDesktops[i]; d.wallpaperPlugin = 'org.kde.image'; d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General'); d.writeConfig('Image', 'file://$abs'); d.writeConfig('FillMode', $fillMode); }" &>/dev/null; then
			log "Wallpaper set (Plasma, D-Bus)"
			return 0
		fi
	fi
	# Fallback: official CLI helper (Plasma 5.21+), does not support fill mode
	if command -v plasma-apply-wallpaperimage &>/dev/null; then
		if plasma-apply-wallpaperimage "$abs" &>/dev/null; then
			log "Wallpaper set (Plasma, plasma-apply-wallpaperimage)"
			return 0
		fi
	fi
	return 1
}

set_wallpaper_xfce() {
	local abs="$1"
	local prop found=1
	while IFS= read -r prop; do
		xfconf-query -c xfce4-desktop -p "$prop" -s "$abs" 2>/dev/null && found=0
	done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$')
	return $found
}

# Set wallpaper by desktop environment
set_wallpaper() {
	local img="$1"
	local style="${2:-fill}"
	# absolute path for URI
	local abs
	abs="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"
	local desktop="${XDG_CURRENT_DESKTOP:-}"

	# The desktop environment decides first: a bare WAYLAND_DISPLAY check would
	# hand every Wayland session to GNOME, including Plasma and Sway.
	case "$desktop" in
		*[Kk][Dd][Ee]*|*[Pp]lasma*)
			set_wallpaper_plasma "$abs" "$style" && return 0
			log "WARNING: Plasma detected but no working setter (install qdbus6 or plasma-apply-wallpaperimage). Trying fallbacks."
			;;
		*[Gg][Nn][Oo][Mm][Ee]*|*[Uu]nity*|*[Cc]innamon*)
			if command -v gsettings &>/dev/null && set_wallpaper_gnome "$abs" "$style"; then
				log "Wallpaper set (GNOME)"
				return 0
			fi
			;;
		*[Xx][Ff][Cc][Ee]*)
			if command -v xfconf-query &>/dev/null && set_wallpaper_xfce "$abs"; then
				log "Wallpaper set (XFCE)"
				return 0
			fi
			;;
		*[Ss]way*)
			: # handled by the SWAYSOCK branch below
			;;
	esac

	if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg &>/dev/null; then
		local sway_mode
		case "$style" in
			fill) sway_mode="fill" ;;
			fit) sway_mode="fit" ;;
			stretch) sway_mode="stretch" ;;
			center) sway_mode="center" ;;
			tile) sway_mode="tile" ;;
			*) sway_mode="fill" ;;
		esac
		swaymsg "output * bg \"$abs\" $sway_mode" &>/dev/null && { log "Wallpaper set (Sway)"; return 0; }
	fi

	# Fallback: feh (works on many WMs: i3, bspwm, etc.)
	if command -v feh &>/dev/null; then
		case "$style" in
			fill)    feh --bg-fill "$abs" ;;
			stretch) feh --bg-scale "$abs" ;;
			fit)     feh --bg-max "$abs" ;;
			center)  feh --bg-center "$abs" ;;
			tile)    feh --bg-tile "$abs" ;;
			*)       feh --bg-fill "$abs" ;;
		esac
		log "Wallpaper set (feh)"
		return 0
	fi

	# Fallback: nitrogen
	if command -v nitrogen &>/dev/null; then
		nitrogen --set-zoom-fill "$abs" &>/dev/null && { log "Wallpaper set (nitrogen)"; return 0; }
	fi

	log "ERROR: No supported wallpaper setter found for XDG_CURRENT_DESKTOP='${desktop:-unset}'. Install feh, or use GNOME/KDE/XFCE/Sway."
	return 1
}

if set_wallpaper "$FILE_PATH" "$STYLE"; then
	log "Done."
else
	exit 1
fi
