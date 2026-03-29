#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMG="${1:-$ROOT_DIR/docs/codex_switch_light.png}"
ICONS_DIR="$SCRIPT_DIR/icons"
ICONSET="$ICONS_DIR/AppIcon.iconset"

mkdir -p "$ICONSET"

sips -z 16 16     "$IMG" --out "$ICONSET/icon_16x16.png"
sips -z 32 32     "$IMG" --out "$ICONSET/icon_16x16@2x.png"
sips -z 32 32     "$IMG" --out "$ICONSET/icon_32x32.png"
sips -z 64 64     "$IMG" --out "$ICONSET/icon_32x32@2x.png"
sips -z 128 128   "$IMG" --out "$ICONSET/icon_128x128.png"
sips -z 256 256   "$IMG" --out "$ICONSET/icon_128x128@2x.png"
sips -z 256 256   "$IMG" --out "$ICONSET/icon_256x256.png"
sips -z 512 512   "$IMG" --out "$ICONSET/icon_256x256@2x.png"
sips -z 512 512   "$IMG" --out "$ICONSET/icon_512x512.png"
sips -z 1024 1024 "$IMG" --out "$ICONSET/icon_512x512@2x.png"

cp "$ICONSET/icon_512x512@2x.png" "$ICONS_DIR/icon.png"

iconutil -c icns "$ICONSET" -o "$ICONS_DIR/AppIcon.icns"
echo "Icon generation completed."
