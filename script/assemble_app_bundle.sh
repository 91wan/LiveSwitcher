#!/usr/bin/env bash

assemble_live_switcher_bundle() {
  local build_dir="$1"
  local signing_policy="$2"
  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local package_dir="$root_dir/Sources/AnnualMeetingSwitcher"
  local app_bundle="$root_dir/dist/LiveSwitcher.app"
  local binary="$build_dir/LiveSwitcher"
  local resource_bundle="$build_dir/LiveSwitcher_LiveSwitcher.bundle"
  local entitlements_file="$package_dir/LiveSwitcher.entitlements"
  local marketing_version
  marketing_version="$(tr -d '[:space:]' < "$root_dir/VERSION")"

  if [[ "$signing_policy" != required && "$signing_policy" != if-available ]]; then
    echo "error: unsupported bundle signing policy: $signing_policy" >&2
    return 2
  fi
  if [[ ! -x "$binary" ]]; then
    echo "error: built binary not found at $binary" >&2
    return 1
  fi

  rm -rf "$app_bundle"
  mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
  cp "$binary" "$app_bundle/Contents/MacOS/LiveSwitcher"
  chmod +x "$app_bundle/Contents/MacOS/LiveSwitcher"

  if [[ -d "$resource_bundle" ]]; then
    cp -R "$resource_bundle" "$app_bundle/Contents/Resources/"
  fi
  if [[ -f "$package_dir/AppIcon.icns" ]]; then
    cp "$package_dir/AppIcon.icns" "$app_bundle/Contents/Resources/AppIcon.icns"
  fi

  cat > "$app_bundle/Contents/Info.plist" << PLIST
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
  <string>$marketing_version</string>
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

  if [[ "$signing_policy" == required ]] || command -v codesign >/dev/null 2>&1; then
    if [[ -f "$entitlements_file" ]]; then
      codesign --force --deep --options runtime --sign - --entitlements "$entitlements_file" "$app_bundle" || return $?
    else
      codesign --force --deep --options runtime --sign - "$app_bundle" || return $?
    fi
    if [[ "$signing_policy" == required ]]; then
      codesign --verify --deep --strict "$app_bundle" || return $?
    fi
  fi
}
