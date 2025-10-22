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
- -s <source.png>   Source icon file (.png or .jpg). Required.
- -b <background>   Optional background image (.png or .jpg).
- -gf <hex>         Gradient start color (hex, e.g. FF0000 or #FF0000).
- -gt <hex>         Gradient end color (hex, e.g. 0000FF or #0000FF).
- -ga <percent>     Gradient alpha (percent). Default 40%.
- -r <size>         Output square size in pixels (single integer). Default 248x248.
- -k                Keep source file name in output (`icon/<name>_<SIZE>.png`). Default is `false`.
- -h                Show usage.

Examples:

1. Generate icon from source only (default 248x248):
   `./android-icon.sh -s assets/logo.png`

2. Generate icon with explicit output size 512x512:
   `./android-icon.sh -s assets/logo.png -r 512`

3. Use a background image and custom size:
   `./android-icon.sh -s assets/logo.png -b assets/bg.jpg -r 360`

4. Add a gradient overlay on top of the background (centered) and custom size:
   `./android-icon.sh -s assets/logo.png -b assets/bg.jpg -gf FF8A00 -gt 0066FF -ga 50 -r 512`

5. Use gradient only (no background image):
   `./android-icon.sh -s assets/logo.png -gf 00FF00 -gt 0000FF -r 300`

## Output

- Temporary working files are written to `temp/`.
- Final icon is written to `icon/ic_launcher_circle_<SIZE>.png`, where `<SIZE>` is the chosen output side (e.g. `icon/ic_launcher_circle_248.png` by default).

## Notes

- The script keeps processing in the source image native resolution and resizes only at the final step to the requested output size.
- If the source image contains transparency, the dominant background color is derived by flattening over white (fallback is white).
- For Windows, running in WSL is recommended for full compatibility.

## Troubleshooting

- If `magick` is not found, ensure ImageMagick is installed and the `magick` binary is on PATH.
- If the script exits with permission errors, run `chmod +x android-icon.sh` and retry.
- Inspect intermediate files in `temp/` to debug compositing steps.