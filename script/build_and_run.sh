#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

APP_BINARY_NAME="LiveSwitcher"
APP_DISPLAY_NAME="LiveSwitcher"
BUNDLE_ID="com.91wan.liveswitcher"
MIN_SYSTEM_VERSION="14.0"
MARKETING_VERSION="0.3.0"
BUILD_VERSION="1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Sources/AnnualMeetingSwitcher"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_BINARY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_BINARY_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$PACKAGE_DIR/AppIcon.icns"
ENTITLEMENTS_FILE="$PACKAGE_DIR/LiveSwitcher.entitlements"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

kill_running_app() {
  pkill -x "$APP_BINARY_NAME" >/dev/null 2>&1 || true
}

build_bundle() {
  local build_binary

  swift build --package-path "$PACKAGE_DIR"
  build_binary="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)/$APP_BINARY_NAME"

  if [[ ! -x "$build_binary" ]]; then
    echo "error: built binary not found at $build_binary" >&2
    exit 1
  fi

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"

  cp "$build_binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  if [[ -f "$ICON_SOURCE" ]]; then
    cp "$ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_BINARY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Allow AppleScript control for presentation playback.</string>
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

  if command -v codesign >/dev/null 2>&1; then
    if [[ -f "$ENTITLEMENTS_FILE" ]]; then
      codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"
    else
      codesign --force --deep --sign - "$APP_BUNDLE"
    fi
  fi
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_launch() {
  sleep 2
  if ! pgrep -x "$APP_BINARY_NAME" >/dev/null 2>&1; then
    echo "error: $APP_BINARY_NAME did not stay running after launch" >&2
    exit 1
  fi
}

stream_process_logs() {
  /usr/bin/log stream --info --style compact --predicate "process == \"$APP_BINARY_NAME\""
}

stream_telemetry() {
  /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
}

kill_running_app
build_bundle

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    exec lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    verify_launch
    stream_process_logs
    ;;
  --telemetry|telemetry)
    open_app
    verify_launch
    stream_telemetry
    ;;
  --verify|verify)
    open_app
    verify_launch
    echo "verified: $APP_BINARY_NAME is running"
    ;;
  *)
    usage
    exit 2
    ;;
esac
