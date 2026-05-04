#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="LiveSwitcher"
APP_BUNDLE_NAME="$APP_NAME.app"
OUT_DIR="$HOME/Downloads"
APP_BUNDLE="$OUT_DIR/$APP_BUNDLE_NAME"
ICON_SRC="$SCRIPT_DIR/AppIcon.icns"
ENTITLEMENTS_FILE="$SCRIPT_DIR/LiveSwitcher.entitlements"

echo "Building $APP_NAME release app..."
swift build -c release
BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

if [[ ! -x "$BINARY" ]]; then
  echo "error: built binary not found at $BINARY" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

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
  <key>CFBundleName</key>
  <string>LiveSwitcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Allow AppleScript control for presentation playback.</string>
  <key>NSAppleScriptEnabled</key>
  <true/>
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
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

codesign --verify --deep --strict "$APP_BUNDLE"
echo "Release app written to $APP_BUNDLE"
