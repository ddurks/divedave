#!/usr/bin/env bash
# Extrude a tight sprite sheet to prevent texture bleed at fractional scale.
#
# Each frame's outermost pixels are replicated outward by EXTRUDE px, producing
# a sheet laid out with margin=EXTRUDE and spacing=2*EXTRUDE — exactly what the
# Phaser (web) and SpriteKit (iOS) loaders expect for "divedave-spritesheet".
#
# Usage: tools/extrude-spritesheet.sh <src.png> <dst.png> [frame_px] [extrude_px]
#   frame_px   side length of one (square) frame   (default 256)
#   extrude_px border replicated around each frame  (default 1)
#
# Requires ImageMagick (`magick`).
set -euo pipefail

SRC="${1:?usage: extrude-spritesheet.sh <src.png> <dst.png> [frame_px] [extrude_px]}"
DST="${2:?usage: extrude-spritesheet.sh <src.png> <dst.png> [frame_px] [extrude_px]}"
FRAME="${3:-256}"
EX="${4:-1}"

W=$(magick identify -format '%w' "$SRC")
H=$(magick identify -format '%h' "$SRC")
COLS=$((W / FRAME))
ROWS=$((H / FRAME))
TILE=$((FRAME + 2 * EX))

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Slice into individual frames (row-major), then edge-replicate each by EX px.
magick "$SRC" -crop "${FRAME}x${FRAME}" +repage "$tmp/t_%03d.png"
for f in "$tmp"/t_*.png; do
  magick "$f" -virtual-pixel Edge \
    -define distort:viewport="${TILE}x${TILE}-${EX}-${EX}" \
    -distort SRT 0 +repage "$f"
done

# Reassemble; tiles are already TILE px so +0+0 spacing yields the padded sheet.
magick montage "$tmp"/t_*.png -tile "${COLS}x${ROWS}" -geometry +0+0 -background none "$DST"

echo "extruded ${COLS}x${ROWS} frames (${FRAME}px, +${EX}px) -> $DST ($(magick identify -format '%wx%h' "$DST"))"
