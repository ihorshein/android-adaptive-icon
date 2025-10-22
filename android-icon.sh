#!/bin/bash
set -e

usage() {
  echo "Usage: -s <source.png> [-b <background.png>] [-gf <hex>] [-gt <hex>] [-ga <percent>] [-r <size>] [-k]"
  echo "  -s: Source icon file, .png or .jpg"
  echo "  -b: Background image file, .png or .jpg"
  echo "  -gf: Gradient from color (hex)"
  echo "  -gt: Gradient to color (hex)"
  echo "  -ga: Gradient alpha (percent). Default 40%"
  echo "  -r: Output square size in pixels (single integer). Default 248x248"
  echo "  -k: Keep source file name in output (icon/<name>_<SIZE>.png). Default is false"
  echo "  -h: Show usage"
  exit 1
}

# Temporary working dir
OUTDIR="temp"
mkdir -p "$OUTDIR"

# Icon directory
ICON_DIR="$(dirname "$OUTDIR")/icon"
mkdir -p "$ICON_DIR"
OUTFILE="$ICON_DIR/ic_launcher_circle_${OUT_SIZE}.png"

# Default output size (square side)
OUT_SIZE=248

# Keep original source name in output (false by default)
KEEP_NAME=0

# Console args parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SRC_ICON="$2"; shift 2 ;;
    -b) SRC_BG="$2"; shift 2 ;;
    -gf) GRADIENT_FROM="$2"; shift 2 ;;
    -gt) GRADIENT_TO="$2"; shift 2 ;;
    -ga) GRADIENT_ALPHA_RAW="$2"; shift 2 ;;
    -r) OUT_SIZE="$2"; shift 2 ;;
    -k) KEEP_NAME=1; shift ;;
    -h) usage ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1"; usage ;;
    *) if [ -z "$SRC_ICON" ]; then SRC_ICON="$1"; shift; else echo "Unexpected arg: $1"; usage; fi ;;
  esac
done

# Validate required args
[ -n "$SRC_ICON" ] || { echo "❌ Specify source icon with -s"; usage; }

# Validate OUT_SIZE (positive integer)
if ! [[ "$OUT_SIZE" =~ ^[0-9]+$ ]] || [ "$OUT_SIZE" -lt 1 ]; then
  echo "❌ Invalid output size: $OUT_SIZE (expect positive integer)"
  exit 1
fi

# If KEEP_NAME enabled, construct output filename from source basename, else default name
if [ "$KEEP_NAME" -eq 1 ]; then
  BASENAME="$(basename "$SRC_ICON")"
  NAME_NO_EXT="${BASENAME%.*}"
  OUTFILE="$ICON_DIR/${NAME_NO_EXT}_${OUT_SIZE}.png"
else
  OUTFILE="$ICON_DIR/ic_launcher_circle_${OUT_SIZE}.png"
fi

# Validate alpha percent, default 40%
if [ -z "$GRADIENT_ALPHA_RAW" ]; then
  GRADIENT_ALPHA="40%"
else
  if [[ "$GRADIENT_ALPHA_RAW" == *% ]]; then GRADIENT_ALPHA="$GRADIENT_ALPHA_RAW"; else GRADIENT_ALPHA="${GRADIENT_ALPHA_RAW}%"; fi
fi

ALPHA_NUM="${GRADIENT_ALPHA%%\%}"
if ! [[ "$ALPHA_NUM" =~ ^[0-9]+$ ]] || [ "$ALPHA_NUM" -lt 0 ] || [ "$ALPHA_NUM" -gt 100 ]; then
  echo "❌ Invalid alpha percent: $GRADIENT_ALPHA (expect 0..100)"
  exit 1
fi

# Determine icon size
ICON_W=$(magick identify -format "%w" "$SRC_ICON")
ICON_H=$(magick identify -format "%h" "$SRC_ICON")
ICON_MAX=$(( ICON_W > ICON_H ? ICON_W : ICON_H ))
SIZE=$ICON_MAX
SHRINK_PERCENT=99

# Dimensions for 248x248 icon
DIAM_BG_BASE=$(( ICON_MAX * 192 / 248 ))
DIAM_ICON_BASE=$(( ICON_MAX * 138 / 248 ))

# Calculate actual diameters
DIAM_BG=$(( DIAM_BG_BASE * SHRINK_PERCENT / 100 ))
[ "$DIAM_BG" -lt 1 ] && DIAM_BG=1
RADIUS_BG=$(( DIAM_BG / 2 ))

DIAM_ICON=$(( DIAM_ICON_BASE * SHRINK_PERCENT / 100 ))
[ "$DIAM_ICON" -lt 1 ] && DIAM_ICON=1
RADIUS_ICON=$(( DIAM_ICON / 2 ))

# Flags
BG_CREATED=0
GRADIENT_CREATED=0

# Prepare bg_full: from provided bg, or gradient, or dominant color
if [ -n "$SRC_BG" ] || { [ -n "$GRADIENT_FROM" ] && [ -n "$GRADIENT_TO" ]; }; then
  BG_CREATED=1
  if [ -n "$SRC_BG" ]; then
    magick "$SRC_BG" -resize ${ICON_MAX}x${ICON_MAX}^ -gravity center -extent ${ICON_MAX}x${ICON_MAX} -alpha set PNG32:"$OUTDIR/bg_full.png"
  else
    magick -size ${ICON_MAX}x${ICON_MAX} xc:none PNG32:"$OUTDIR/bg_full.png"
  fi

  if [ -n "$GRADIENT_FROM" ] && [ -n "$GRADIENT_TO" ]; then
    GRADIENT_CREATED=1
    [[ "$GRADIENT_FROM" != \#* ]] && GRADIENT_FROM="#$GRADIENT_FROM"
    [[ "$GRADIENT_TO" != \#* ]] && GRADIENT_TO="#$GRADIENT_TO"
    magick -size ${SIZE}x${SIZE} gradient:"$GRADIENT_FROM"-"$GRADIENT_TO" -alpha set -channel A -evaluate set "$GRADIENT_ALPHA" +channel PNG32:"$OUTDIR/gradient_full.png"
  fi
else
  # Derive dominant color (flatten to white to ignore transparency), fallback to white
  DOM_HEX="$(magick "$SRC_ICON" -background white -alpha remove -flatten -colorspace sRGB -resize 4x4\! -format "%[hex:p{0,0}]" info:- 2>/dev/null || true)"
  if [ -n "$DOM_HEX" ]; then
    DOM_COLOR="#${DOM_HEX}"
  else
    DOM_COLOR="#FFFFFF"
  fi
  magick -size ${ICON_MAX}x${ICON_MAX} "xc:${DOM_COLOR}" -alpha set PNG32:"$OUTDIR/bg_full.png"
  BG_CREATED=1
fi

# Prepare square icon
magick "$SRC_ICON" -gravity center -background none -extent ${ICON_MAX}x${ICON_MAX} PNG32:"$OUTDIR/icon_square.png"

if [ "$BG_CREATED" -eq 1 ]; then
  magick "$OUTDIR/bg_full.png" "$OUTDIR/icon_square.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/composite_full.png"
else
  cp "$OUTDIR/icon_square.png" "$OUTDIR/composite_full.png"
fi

# Mask for background circle
magick -size ${DIAM_BG}x${DIAM_BG} xc:none -fill white -draw "circle $RADIUS_BG,$RADIUS_BG $DIAM_BG,$RADIUS_BG" PNG32:"$OUTDIR/mask_bg.png"

if [ "$BG_CREATED" -eq 1 ]; then
  SRC_BG_LAYER="$OUTDIR/bg_full.png"
  magick "$SRC_BG_LAYER" -gravity center -crop ${DIAM_BG}x${DIAM_BG}+0+0 +repage PNG32:"$OUTDIR/bg_cropped.png"
  if [ "$GRADIENT_CREATED" -eq 1 ]; then
    magick "$OUTDIR/gradient_full.png" -gravity center -crop ${DIAM_BG}x${DIAM_BG}+0+0 +repage PNG32:"$OUTDIR/gradient_crop_bg.png"
    magick "$OUTDIR/bg_cropped.png" "$OUTDIR/gradient_crop_bg.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/bg_cropped_with_grad.png"
    magick "$OUTDIR/bg_cropped_with_grad.png" "$OUTDIR/mask_bg.png" -compose CopyOpacity -composite PNG32:"$OUTDIR/bg_circle.png"
  else
    magick "$OUTDIR/bg_cropped.png" "$OUTDIR/mask_bg.png" -compose CopyOpacity -composite PNG32:"$OUTDIR/bg_circle.png"
  fi
else
  magick -size ${DIAM_BG}x${DIAM_BG} xc:none PNG32:"$OUTDIR/bg_circle.png"
fi

# Base with bg circle
magick -size ${SIZE}x${SIZE} xc:none "$OUTDIR/bg_circle.png" -gravity center -composite PNG32:"$OUTDIR/base.png"

# Mask for icon circle
magick -size ${DIAM_ICON}x${DIAM_ICON} xc:none -fill white -draw "circle $RADIUS_ICON,$RADIUS_ICON $DIAM_ICON,$RADIUS_ICON" PNG32:"$OUTDIR/mask_icon.png"

if [ "$BG_CREATED" -eq 1 ]; then
  SRC_BG_LAYER="$OUTDIR/bg_full.png"
  magick "$SRC_BG_LAYER" -gravity center -crop ${DIAM_ICON}x${DIAM_ICON}+0+0 +repage PNG32:"$OUTDIR/bg_scaled_small.png"
else
  magick -size ${DIAM_ICON}x${DIAM_ICON} xc:none PNG32:"$OUTDIR/bg_scaled_small.png"
fi

# Scale icon to inner circle
magick "$OUTDIR/icon_square.png" -resize ${DIAM_ICON}x${DIAM_ICON}^ -gravity center -background none -extent ${DIAM_ICON}x${DIAM_ICON} PNG32:"$OUTDIR/icon_scaled_only.png"

if [ "$GRADIENT_CREATED" -eq 1 ]; then
  magick "$OUTDIR/gradient_full.png" -gravity center -crop ${DIAM_ICON}x${DIAM_ICON}+0+0 +repage PNG32:"$OUTDIR/gradient_crop_icon.png"
  magick "$OUTDIR/bg_scaled_small.png" "$OUTDIR/gradient_crop_icon.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/bg_with_grad_small.png"
  magick "$OUTDIR/bg_with_grad_small.png" "$OUTDIR/icon_scaled_only.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/content_small.png"
else
  magick "$OUTDIR/bg_scaled_small.png" "$OUTDIR/icon_scaled_only.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/content_small.png"
fi

magick "$OUTDIR/content_small.png" "$OUTDIR/mask_icon.png" -compose CopyOpacity -composite PNG32:"$OUTDIR/icon_circle.png"

magick "$OUTDIR/base.png" "$OUTDIR/icon_circle.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/ic_launcher_circle_full.png"

# Final compose and resize to output (uses OUT_SIZE)
magick "$OUTDIR/ic_launcher_circle_full.png" -resize ${OUT_SIZE}x${OUT_SIZE} PNG32:"$OUTFILE"

echo "✅ Done: $OUTFILE"