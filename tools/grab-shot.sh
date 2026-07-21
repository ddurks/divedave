#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="$ROOT/promo/screenshots"
mkdir -p "$OUT"

if ! command -v magick >/dev/null; then
    echo "Need ImageMagick (brew install imagemagick) to strip the alpha channel." >&2
    exit 1
fi

if [ "$(xcrun simctl list devices booted | grep -c Booted)" -ne 1 ]; then
    echo "Need exactly one booted simulator. Booted now:" >&2
    xcrun simctl list devices booted >&2
    exit 1
fi

if [ $# -ge 1 ]; then
    DEST="$OUT/$1.png"
else
    n=1
    while [ -f "$OUT/$(printf 'shot-%02d.png' "$n")" ]; do n=$((n + 1)); done
    DEST="$OUT/$(printf 'shot-%02d.png' "$n")"
fi

xcrun simctl io booted screenshot "$DEST"
# App Store Connect rejects screenshots with an alpha channel; simctl always adds one.
magick "$DEST" -alpha off -strip "PNG24:$DEST"
echo "$DEST  ($(sips -g pixelWidth -g pixelHeight "$DEST" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w" x "h}'))"
