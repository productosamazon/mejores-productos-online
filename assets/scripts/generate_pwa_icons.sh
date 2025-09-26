#!/usr/bin/env bash
# Generate PWA icons (192/512) and base_image.png from the hero image (first -900 image found in assets/images)
# Usage: chmod +x assets/scripts/generate_pwa_icons.sh && ./assets/scripts/generate_pwa_icons.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGES_DIR="$ROOT_DIR/images"
ICONS_DIR="$ROOT_DIR/icons"
mkdir -p "$ICONS_DIR"

# Find a hero image (prefer *_-900.* variants produced by fetch script)
hero_candidate=""
for ext in webp jpg jpeg png; do
  candidate=$(ls "$IMAGES_DIR"/*-900."$ext" 2>/dev/null | head -n1 || true)
  if [ -n "$candidate" ]; then
    hero_candidate="$candidate"
    break
  fi
done

if [ -z "$hero_candidate" ]; then
  echo "No hero image found in $IMAGES_DIR matching *-900.(webp|jpg|png). Please run assets/scripts/fetch_and_convert_images.sh first or place a hero image at $IMAGES_DIR/hero-900.png"
  exit 1
fi

echo "Using hero image: $hero_candidate"

base_png="$ICONS_DIR/base_image.png"
icon_192="$ICONS_DIR/icon-192.png"
icon_512="$ICONS_DIR/icon-512.png"
favicon="$ICONS_DIR/favicon.ico"

# Convert hero to a square centered PNG base, then produce 192 and 512 icons and a favicon
if command -v convert >/dev/null 2>&1; then
  # Make a square by padding then resizing to a large size before downscaling
  convert "$hero_candidate" -auto-orient -resize 1200x1200^ -gravity center -extent 1200x1200 -strip "$base_png"
  convert "$base_png" -resize 192x192 "$icon_192"
  convert "$base_png" -resize 512x512 "$icon_512"
  # favicon with multiple sizes
  convert "$icon_192" "$icon_512" -colors 256 "$favicon"
  echo "Generated $base_png, $icon_192, $icon_512, $favicon"
else
  echo "ImageMagick 'convert' not found. Cannot generate icons. Install ImageMagick and retry."
  exit 1
fi

# Optional: generate WebP variants of icons if cwebp is available
if command -v cwebp >/dev/null 2>&1; then
  cwebp -q 85 "$icon_192" -o "$ICONS_DIR/icon-192.webp" >/dev/null 2>&1 || true
  cwebp -q 85 "$icon_512" -o "$ICONS_DIR/icon-512.webp" >/dev/null 2>&1 || true
  echo "Also created WebP icon variants"
fi

exit 0
