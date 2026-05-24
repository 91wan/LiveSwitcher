#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="LiveSwitcher"
APP_BUNDLE_NAME="$APP_NAME.app"
OUT_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$OUT_DIR/$APP_BUNDLE_NAME"
ICON_SRC="$SCRIPT_DIR/AppIcon.icns"
ENTITLEMENTS_FILE="$SCRIPT_DIR/LiveSwitcher.entitlements"
MARKETING_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"

echo "Building $APP_NAME release app..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
BINARY="$BUILD_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BUILD_DIR/LiveSwitcher_LiveSwitcher.bundle"

if [[ ! -x "$BINARY" ]]; then
  echo "error: built binary not found at $BINARY" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>LiveSwitcher</string>
  <key>CFBundleExecutable</key>
  <string>LiveSwitcher</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.91wan.liveswitcher</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundleName</key>
  <string>LiveSwitcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Allow AppleScript control for presentation playback.</string>
  <key>NSAppleScriptEnabled</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>Allow keyboard-event monitoring for PPT mode and presentation remote control.</string>
  <key>NSCameraUsageDescription</key>
  <string>Allow camera access for live input monitoring.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Allow microphone access for audio monitoring.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -f "$ENTITLEMENTS_FILE" ]]; then
  codesign --force --deep --options runtime --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"
else
  codesign --force --deep --options runtime --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict "$APP_BUNDLE"
echo "Release app written to $APP_BUNDLE"
