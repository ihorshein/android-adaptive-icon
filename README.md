# Android Adaptive Icon Tool

Shell script to generate an [Adaptive Android-style launcher](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive) icon from a source image, optional background, and optional gradient overlay.

The script uses `ImageMagick`.

## Requirements

- ImageMagick (magick CLI)
  - macOS: `brew install imagemagick`
  - Debian/Ubuntu: `sudo apt update && sudo apt install imagemagick`
  - Fedora: `sudo dnf install imagemagick`
  - Windows: Install [ImageMagick](https://imagemagick.org/script/download.php) or use WSL

- Bash (Linux, macOS, or WSL on Windows)

## Install

1. Make sure ImageMagick is installed and `magick` is available in PATH.
2. Make the script executable:
   `chmod +x android-icon.sh`

## Usage

Basic syntax:
`./android-icon.sh -s <source.png> [options]`

Or simply:
`./android-icon.sh <source.png>`

Options:
- `-s <source.png>`   Source icon file (.png or .jpg). **Required.**
- `-bg <background>`  Optional background image (.png or .jpg). If omitted, a solid color is used (dominant color from source or white).
- `-gf <hex>`         Gradient start color (hex, e.g. FF0000 or #FF0000).
- `-gt <hex>`         Gradient end color (hex, e.g. 0000FF or #0000FF).
- `-ga <percent>`     Gradient alpha (opacity, percent). Default is 40%.
- `-sc <factor>`      Icon scale factor inside the inner circle (number, e.g. 1.2). Default is sqrt(1).
- `-r <size>`         Output square size in pixels (single integer). Default is 248x248.
- `-k`                Keep source file name in output (`icon/<name>_<SIZE>.png`). Default is `false`.
- `-h`                Show usage/help.

**Notes on parameters:**
- If both `-bg` and gradient (`-gf`, `-gt`) are specified, the gradient overlays the background image.
- If only gradient is specified, the icon uses a gradient background.
- If neither is specified, the dominant color from the source icon is used as background.
- The scale factor (`-sc`) controls how much the icon fills the inner circle. Use values >1 to shrink, <1 to enlarge (default fits icon to inner circle).

### Icon Scaling (`-sc` parameter)

The `-sc` parameter controls how much the icon is scaled inside the inner circle of the adaptive icon.
- The value is a number or expression (e.g. `1.2`).
- The icon is resized so that its largest side fits into the inner circle divided by the scale factor.
- **Default:** `sqrt(1)` (no scaling, icon fits exactly into the inner circle).
- **Larger values (>1):** The icon will appear smaller inside the inner circle (more padding).
- **Smaller values (<1):** The icon will appear larger, possibly overflowing the inner circle.

**Examples:**
- `-sc 1.5` — The icon will be scaled down to 2/3 of the inner circle diameter.
- `-sc 1` — The icon will fill the inner circle exactly.
- `-sc 0.8` — The icon will be scaled up, possibly cropped by the inner circle mask.

**Tip:** Use values between `1` and `2` for best results.  
If you want the icon to have more space around it, increase the scale factor.


### Examples:

1. Generate icon from source only (default 248x248):
   `./android-icon.sh -s assets/logo.png`

2. Generate icon with explicit output size 512x512:
   `./android-icon.sh -s assets/logo.png -r 512`

3. Use a background image and custom size:
   `./android-icon.sh -s assets/logo.png -bg assets/bg.jpg -r 360`

4. Add a gradient overlay on top of the background and custom size:
   `./android-icon.sh -s assets/logo.png -bg assets/bg.jpg -gf FF8A00 -gt 0066FF -ga 50 -r 512`

5. Use gradient only (no background image):
   `./android-icon.sh -s assets/logo.png -gf 00FF00 -gt 0000FF -r 300`

6. Custom icon scale factor (icon shrunk inside inner circle):
   `./android-icon.sh -s assets/logo.png -sc 1.5 -r 512`

## Output

- Temporary working files are written to `temp/`.
- Final icon is written to `icon/ic_launcher_circle_<SIZE>.png`, or `icon/<source_name>_<SIZE>.png` if `-k` is used.

## Features & Details

- The script processes the source image at its native resolution and resizes only at the final step to the requested output size.
- If the source image contains transparency, the dominant background color is derived by flattening over white (fallback is white).
- The icon is centered and fitted into the inner circle, with optional scaling via `-sc`.
- Background can be a solid color, a gradient, or a custom image (with optional gradient overlay).
- For Windows, running in WSL is recommended for full compatibility.

## Troubleshooting

- If `magick` is not found, ensure ImageMagick is installed and the `magick` binary is on PATH.
- If the script exits with permission errors, run `chmod +x android-icon.sh` and retry.
- Inspect intermediate files in `temp/` to debug compositing steps.