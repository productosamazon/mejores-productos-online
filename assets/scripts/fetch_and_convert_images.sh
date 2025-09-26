#!/usr/bin/env bash
# Fetch product page OG images and convert to WebP and AVIF in multiple sizes (600/900/1200)
# Usage: chmod +x fetch_and_convert_images.sh && ./fetch_and_convert_images.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGES_DIR="$ROOT_DIR/images"
mkdir -p "$IMAGES_DIR"

# Requirements:
# python3, pip install requests beautifulsoup4 pillow
# ImageMagick (convert) and cwebp (libwebp) and avifenc (libavif)

PRODUCTS=(
  "ropa-chaqueta|https://amzn.to/48xXued"
  "ropa-zapatillas|https://amzn.to/4nnphmn"
  "ropa-jeans|https://amzn.to/4nH6x0M"
  "ropa-camiseta|https://amzn.to/4mtoTBn"
  "ropa-deportiva|https://amzn.to/4nMvl7G"
  "ropa-abrigo|https://amzn.to/4nIAeyp"
  "ropa-accesorios|https://amzn.to/48vzHLU"
  "ropa-casual|https://amzn.to/48y3fsm"
  
  "ordenadores-laptop|https://amzn.to/3VyHjpm"
  "ordenadores-oficina|https://amzn.to/4nR1U4w"
  "ordenadores-monitor|https://amzn.to/3VzmoTg"
  "ordenadores-teclado|https://amzn.to/46xCq4Y"
  "ordenadores-raton|https://amzn.to/4ngViMH"
  "ordenadores-silla|https://amzn.to/426KkB8"
  "ordenadores-tablet|https://amzn.to/4pAdt1D"
  "ordenadores-accesorios|https://amzn.to/4nIAKMR"
  
  "sartenes-ceramica|https://amzn.to/46CXvLp"
  "sartenes-ollas|https://amzn.to/46zDHZh"
  "sartenes-hierro|https://amzn.to/4gNR4tK"
  "sartenes-olla-presion|https://amzn.to/4nH7EO0"
  "sartenes-bateria|https://amzn.to/427Yz8F"
  "sartenes-utensilios|https://amzn.to/4mu1Iah"
  "sartenes-titanio|https://amzn.to/4mzB2Vx"
  "sartenes-accesorios|https://amzn.to/46ZwFgT"
)

sizes=(600 900 1200)

download_image() {
  local url="$1"
  local out="$2"
  # Use python3 to fetch page and extract og:image or twitter:image
  python3 - <<PY > /tmp/og_url.txt
import sys,requests
from bs4 import BeautifulSoup
url = sys.argv[1]
try:
    r = requests.get(url, headers={'User-Agent':'Mozilla/5.0'}, timeout=15)
    soup = BeautifulSoup(r.text, 'html.parser')
    meta = soup.find('meta', property='og:image') or soup.find('meta', attrs={'name':'twitter:image'})
    if meta and meta.get('content'):
        print(meta.get('content'))
except Exception as e:
    pass
PY
  /tmp/og_url.txt="$(cat /tmp/og_url.txt)"
  og_url=$(cat /tmp/og_url.txt)
  if [ -z "$og_url" ]; then
    echo "No OG image found for $url; attempting direct download of URL"
    curl -sL "$url" -o "$out" || return 1
  else
    echo "Downloading image: $og_url"
    curl -sL "$og_url" -o "$out" || return 1
  fi
}

for entry in "${PRODUCTS[@]}"; do
  slug="${entry%%|*}"
  url="${entry#*|}"
  orig_file="$IMAGES_DIR/${slug}-orig"
  echo "Processing $slug -> $url"
  # download best-effort
  tmpfile="${orig_file}.jpg"
  if download_image "$url" "$tmpfile"; then
    for s in "${sizes[@]}"; do
      out_webp="$IMAGES_DIR/${slug}-${s}.webp"
      out_avif="$IMAGES_DIR/${slug}-${s}.avif"
      echo "Generating $out_webp and $out_avif"
      # resize with ImageMagick if available
      if command -v convert >/dev/null 2>&1; then
        convert "$tmpfile" -resize ${s}x -quality 85 "${tmpfile%.*}-${s}.jpg"
        if command -v cwebp >/dev/null 2>&1; then
          cwebp -q 85 "${tmpfile%.*}-${s}.jpg" -o "$out_webp" >/dev/null 2>&1 || true
        else
          convert "${tmpfile%.*}-${s}.jpg" "$out_webp" >/dev/null 2>&1 || true
        fi
        if command -v avifenc >/dev/null 2>&1; then
          avifenc --min 20 --max 45 "${tmpfile%.*}-${s}.jpg" "$out_avif" >/dev/null 2>&1 || true
        else
          echo "avifenc not found; skipping AVIF for $slug $s"
        fi
      else
        echo "ImageMagick convert not found; copying original"
        cp "$tmpfile" "$IMAGES_DIR/${slug}-${s}.jpg" || true
      fi
    done
    # cleanup temporary resized jpgs
    rm -f ${tmpfile%.*}-*.jpg || true
  else
    echo "Failed to download image for $slug"
  fi
done

echo "Done. Generated images in $IMAGES_DIR"