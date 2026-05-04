#!/usr/bin/env bash
set -euo pipefail

SUITE_NAME="${LIVESWITCHER_DEMO_SUITE:-com.91wan.liveswitcher.demo}"
DEMO_DIR="${TMPDIR:-/tmp}/liveswitcher-demo-assets"

mkdir -p "$DEMO_DIR"

touch \
  "$DEMO_DIR/Opening Video.mov" \
  "$DEMO_DIR/Product Highlights.mov" \
  "$DEMO_DIR/Dinner Loop.mov" \
  "$DEMO_DIR/Walk-in Music.mp3" \
  "$DEMO_DIR/Award Moment.mp3" \
  "$DEMO_DIR/Closing Bed.mp3"

cat >"$DEMO_DIR/Neutral Wallpaper.ppm" <<'PPM'
P3
2 2
255
12 24 48  20 98 180
20 98 180  12 24 48
PPM

/usr/bin/sips -s format png "$DEMO_DIR/Neutral Wallpaper.ppm" --out "$DEMO_DIR/Neutral Wallpaper.png" >/dev/null
rm -f "$DEMO_DIR/Neutral Wallpaper.ppm"

defaults delete "$SUITE_NAME" >/dev/null 2>&1 || true
defaults write "$SUITE_NAME" pushList_paths -array \
  "$DEMO_DIR/Opening Video.mov" \
  "$DEMO_DIR/Product Highlights.mov" \
  "$DEMO_DIR/Dinner Loop.mov"
defaults write "$SUITE_NAME" pushList_titles -array \
  "Opening Video" \
  "Product Highlights" \
  "Dinner Loop"
defaults write "$SUITE_NAME" pushList_subtitles -array \
  "VIDEO" \
  "VIDEO" \
  "VIDEO"

defaults write "$SUITE_NAME" bgmList_paths -array \
  "$DEMO_DIR/Walk-in Music.mp3" \
  "$DEMO_DIR/Award Moment.mp3" \
  "$DEMO_DIR/Closing Bed.mp3"
defaults write "$SUITE_NAME" bgmList_titles -array \
  "Walk-in Music" \
  "Award Moment" \
  "Closing Bed"
defaults write "$SUITE_NAME" bgmList_categories -array \
  "暖场音乐" \
  "暖场音乐" \
  "暖场音乐"

defaults write "$SUITE_NAME" backgroundWallpapers_paths -array "$DEMO_DIR/Neutral Wallpaper.png"
defaults write "$SUITE_NAME" activeWallpaper_path "$DEMO_DIR/Neutral Wallpaper.png"
defaults write "$SUITE_NAME" audioStrategy "混合"
defaults write "$SUITE_NAME" speakerMode -bool false
defaults write "$SUITE_NAME" autoPlayNextVideoOnEnd -bool false

echo "Seeded LiveSwitcher demo data in suite: $SUITE_NAME"
echo "Launch with: LIVESWITCHER_USER_DEFAULTS_SUITE=$SUITE_NAME ./dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher"
