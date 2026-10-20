#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="LiveSwitcher"
APP_BUNDLE="$REPO_ROOT/dist/$APP_NAME.app"
# Preserve VERSION read failures before build preparation.
tr -d '[:space:]' < "$REPO_ROOT/VERSION" >/dev/null
source "$REPO_ROOT/script/assemble_app_bundle.sh"

echo "Building $APP_NAME release app..."
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
assemble_live_switcher_bundle "$BUILD_DIR" required
echo "Release app written to $APP_BUNDLE"
