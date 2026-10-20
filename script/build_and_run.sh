#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

APP_BINARY_NAME="LiveSwitcher"
BUNDLE_ID="com.91wan.liveswitcher"
# Preserve VERSION read failures before build/launch preparation.
tr -d '[:space:]' < "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION" >/dev/null

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Sources/AnnualMeetingSwitcher"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_BINARY_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_BINARY_NAME"
source "$ROOT_DIR/script/assemble_app_bundle.sh"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

kill_running_app() {
  pkill -x "$APP_BINARY_NAME" >/dev/null 2>&1 || true
}

build_bundle() {
  local build_dir

  swift build --package-path "$PACKAGE_DIR"
  build_dir="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"
  assemble_live_switcher_bundle "$build_dir" if-available
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

main() {
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
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
