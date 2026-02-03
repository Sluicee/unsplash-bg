#!/bin/bash
cd "$(dirname "$0")"

if [[ ! -f "config.json" ]]; then
	if [[ -f "config.json.template" ]]; then
		echo "Creating config.json from template..."
		cp "config.json.template" "config.json"
		echo "Config created. Edit config.json and set unsplash.accessKey, then run again."
	else
		echo "ERROR: config.json.template not found."
		exit 1
	fi
	exit 0
fi

echo "Changing wallpaper..."
exec ./scripts/unsplash-bg.sh
