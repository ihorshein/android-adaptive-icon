#!/bin/bash
set -e

usage() {
  echo "Usage: -s <source.png> [-b <background.png>] [-gf <hex>] [-gt <hex>] [-ga <percent>] [-r <size>] [-k]"
  echo "  -s: Source icon file, .png or .jpg"
  echo "  -bg: Background image file, .png or .jpg"
  echo "  -gf: Gradient from color (hex)"
  echo "  -gt: Gradient to color (hex)"
  echo "  -ga: Gradient alpha (percent). Default 40%"
  echo "  -sc: Icon scale factor inside inner circle (number). Default sqrt(2)"
  echo "  -r: Output square size in pixels (single integer). Default 248x248"
  echo "  -k: Keep source file name in output (icon/<name>_<SIZE>.png). Default is false"
  echo "  -h: Show usage"
  exit 1
}

OUTDIR="temp"
mkdir -p "$OUTDIR"
ICON_DIR="$(dirname "$OUTDIR")/icon"
mkdir -p "$ICON_DIR"

OUT_SIZE=248
KEEP_NAME=0
ICON_SCALE="sqrt(1.2)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SRC_ICON="$2"; shift 2 ;;
    -bg) SRC_BG="$2"; shift 2 ;;
    -gf) GRADIENT_FROM="$2"; shift 2 ;;
    -gt) GRADIENT_TO="$2"; shift 2 ;;
    -ga) GRADIENT_ALPHA_RAW="$2"; shift 2 ;;
    -sc) ICON_SCALE="$2"; shift 2 ;;
    -r) OUT_SIZE="$2"; shift 2 ;;
    -k) KEEP_NAME=1; shift ;;
    -h) usage ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1"; usage ;;
    *) if [ -z "$SRC_ICON" ]; then SRC_ICON="$1"; shift; else echo "Unexpected arg: $1"; usage; fi ;;
  esac
done

[ -n "$SRC_ICON" ] || { echo "❌ Specify source icon with -s"; usage; }

if ! [[ "$OUT_SIZE" =~ ^[0-9]+$ ]] || [ "$OUT_SIZE" -lt 1 ]; then
  echo "❌ Invalid output size: $OUT_SIZE (expect positive integer)"
  exit 1
fi

if [ "$KEEP_NAME" -eq 1 ]; then
  BASENAME="$(basename "$SRC_ICON")"
  NAME_NO_EXT="${BASENAME%.*}"
  OUTFILE="$ICON_DIR/${NAME_NO_EXT}_${OUT_SIZE}.png"
else
  OUTFILE="$ICON_DIR/ic_launcher_circle_${OUT_SIZE}.png"
fi

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

# Determine sizes
ICON_W=$(magick identify -format "%w" "$SRC_ICON")
ICON_H=$(magick identify -format "%h" "$SRC_ICON")
ICON_MAX=$(( ICON_W > ICON_H ? ICON_W : ICON_H ))
SIZE=$OUT_SIZE

# Diameters of circles (fit into 192x192 and 138x138 relative to OUT_SIZE)
DIAM_OUTER=$(( SIZE * 192 / 248 ))
DIAM_INNER=$(( SIZE * 138 / 248 ))

RADIUS_OUTER=$(( DIAM_OUTER / 2 ))
RADIUS_INNER=$(( DIAM_INNER / 2 ))

# 1. Create background (image/gradient/color)
if [ -n "$SRC_BG" ]; then
  magick "$SRC_BG" -resize ${DIAM_OUTER}x${DIAM_OUTER}^ -gravity center -extent ${DIAM_OUTER}x${DIAM_OUTER} -alpha set PNG32:"$OUTDIR/bg_base.png"
  if [ -n "$GRADIENT_FROM" ] && [ -n "$GRADIENT_TO" ]; then
    [[ "$GRADIENT_FROM" != \#* ]] && GRADIENT_FROM="#$GRADIENT_FROM"
    [[ "$GRADIENT_TO" != \#* ]] && GRADIENT_TO="#$GRADIENT_TO"
    magick -size ${DIAM_OUTER}x${DIAM_OUTER} gradient:"$GRADIENT_FROM"-"$GRADIENT_TO" -alpha set -channel A -evaluate set "$GRADIENT_ALPHA" +channel PNG32:"$OUTDIR/bg_gradient.png"
    magick "$OUTDIR/bg_base.png" "$OUTDIR/bg_gradient.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/bg.png"
  else
    cp "$OUTDIR/bg_base.png" "$OUTDIR/bg.png"
  fi
elif [ -n "$GRADIENT_FROM" ] && [ -n "$GRADIENT_TO" ]; then
  [[ "$GRADIENT_FROM" != \#* ]] && GRADIENT_FROM="#$GRADIENT_FROM"
  [[ "$GRADIENT_TO" != \#* ]] && GRADIENT_TO="#$GRADIENT_TO"
  magick -size ${DIAM_OUTER}x${DIAM_OUTER} gradient:"$GRADIENT_FROM"-"$GRADIENT_TO" -alpha set -channel A -evaluate set "$GRADIENT_ALPHA" +channel PNG32:"$OUTDIR/bg.png"
else
  DOM_HEX="$(magick "$SRC_ICON" -background white -alpha remove -flatten -colorspace sRGB -resize 4x4\! -format "%[hex:p{0,0}]" info:- 2>/dev/null || true)"
  [ -n "$DOM_HEX" ] && DOM_COLOR="#${DOM_HEX}" || DOM_COLOR="#FFFFFF"
  magick -size ${DIAM_OUTER}x${DIAM_OUTER} "xc:${DOM_COLOR}" -alpha set PNG32:"$OUTDIR/bg.png"
fi

# 2. Mask for outer circle
magick -size ${DIAM_OUTER}x${DIAM_OUTER} xc:none -fill white -draw "circle $RADIUS_OUTER,$RADIUS_OUTER $(($DIAM_OUTER-1)),$RADIUS_OUTER" PNG32:"$OUTDIR/mask_outer.png"
magick "$OUTDIR/bg.png" -gravity center -crop ${DIAM_OUTER}x${DIAM_OUTER}+0+0 +repage PNG32:"$OUTDIR/bg_outer.png"
magick "$OUTDIR/bg_outer.png" "$OUTDIR/mask_outer.png" -compose CopyOpacity -composite PNG32:"$OUTDIR/circle_outer.png"

# 3. Mask for inner circle
magick -size ${DIAM_INNER}x${DIAM_INNER} xc:none -fill white -draw "circle $RADIUS_INNER,$RADIUS_INNER $(($DIAM_INNER-1)),$RADIUS_INNER" PNG32:"$OUTDIR/mask_inner.png"
magick "$OUTDIR/bg.png" -gravity center -crop ${DIAM_INNER}x${DIAM_INNER}+0+0 +repage PNG32:"$OUTDIR/bg_inner.png"
magick "$OUTDIR/bg_inner.png" "$OUTDIR/mask_inner.png" -compose CopyOpacity -composite PNG32:"$OUTDIR/circle_inner.png"

# 4. Fit icon into inner circle, scale evenly, preserve transparency
SIDE_ICON_IN_CIRCLE=$(awk "BEGIN {printf \"%d\", ${DIAM_INNER}/${ICON_SCALE}}")
[ "$SIDE_ICON_IN_CIRCLE" -lt 1 ] && SIDE_ICON_IN_CIRCLE=1
magick "$SRC_ICON" -resize ${SIDE_ICON_IN_CIRCLE}x${SIDE_ICON_IN_CIRCLE} -gravity center -background none -extent ${DIAM_INNER}x${DIAM_INNER} PNG32:"$OUTDIR/icon_fitted.png"
magick "$OUTDIR/circle_inner.png" "$OUTDIR/icon_fitted.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/inner_with_icon.png"

# 5. Compose final icon: outer circle, then inner with icon on top
magick -size ${SIZE}x${SIZE} xc:none "$OUTDIR/circle_outer.png" -gravity center -composite PNG32:"$OUTDIR/base.png"
magick "$OUTDIR/base.png" "$OUTDIR/inner_with_icon.png" -gravity center -compose Over -composite PNG32:"$OUTDIR/ic_launcher_circle_full.png"

# 6. Final resize and output
magick "$OUTDIR/ic_launcher_circle_full.png" -resize ${OUT_SIZE}x${OUT_SIZE} PNG32:"$OUTFILE"

echo "✅ Done: $OUTFILE"