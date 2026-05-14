#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "release hygiene failed: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

require_file VERSION

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"
CURRENT_TAG="v$CURRENT_VERSION"
PREVIOUS_VERSION="0.3.8"
PREVIOUS_TAG="v$PREVIOUS_VERSION"

require_file README.md
require_file README_ZH.md
require_file docs/assets/readme/preview-switch.png
require_file docs/assets/readme/audio-mixer.png
require_file docs/assets/readme/overlays.png
require_file script/check_workspace_guard.sh
require_file script/test_workspace_guard.sh
require_file "docs/qa/release-hygiene-v$CURRENT_VERSION.md"
require_file "docs/qa/workspace-guard-v$CURRENT_VERSION.md"

search_pattern() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "$@"
  else
    grep -R -n -E \
      --exclude-dir=.git \
      --exclude-dir=.build \
      --exclude-dir=dist \
      --exclude='*.icns' \
      --exclude='*.png' \
      --exclude='*.zip' \
      "$pattern" "$@"
  fi
}

private_pattern="$(
  printf '%s|%s|Ditu%s|com\\.didu|%s|%s|%s' \
    "$(printf '\346\227\240\351\224\241')" \
    "$(printf '\345\270\235\351\203\275')" \
    "LiveSwitcher" \
    "$(printf '\345\256\242\346\210\267\357\274\232')" \
    "$(printf '\347\247\201\346\234\211')" \
    "$(printf '\344\273\205\351\231\220\345\206\205\351\203\250')"
)"

local_path_pattern="/Users/""liuchangxi|Downloads/app""图标|V33_""五功能版|V2026""0306"

search_pattern "$private_pattern" . \
  && fail "private/customer string found"

search_pattern "$local_path_pattern" . \
  && fail "local/private path found"

previous_version_pattern="$(printf '%s' "$PREVIOUS_VERSION" | sed 's/[.]/\\./g')"
search_pattern "${previous_version_pattern}|${PREVIOUS_TAG}|LiveSwitcher-macOS-${PREVIOUS_TAG}" \
  Sources script/build_and_run.sh Sources/AnnualMeetingSwitcher/build_v33.sh .github \
  && fail "stale active version reference found"

search_pattern "static let appVersion = \"$CURRENT_VERSION\"" Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/AppConfiguration.swift >/dev/null \
  || fail "AppConfiguration version is not $CURRENT_VERSION"

grep -qx "$CURRENT_VERSION" VERSION \
  || fail "VERSION file is not $CURRENT_VERSION"

search_pattern "LiveSwitcher-macOS-$CURRENT_TAG.zip" README.md README_ZH.md >/dev/null \
  || fail "README release asset does not point at $CURRENT_TAG"

search_pattern "workspace-guard-v$CURRENT_VERSION" README.md README_ZH.md >/dev/null \
  || fail "README workspace guard docs do not point at $CURRENT_TAG"

search_pattern '\[中文\]\(README_ZH\.md\)' README.md >/dev/null \
  || fail "README.md does not link to README_ZH.md"

search_pattern '\[English\]\(README\.md\)' README_ZH.md >/dev/null \
  || fail "README_ZH.md does not link to README.md"

search_pattern 'not notarized|No License|no open-source license' README.md >/dev/null \
  || fail "README.md missing notarization or license notice"

search_pattern '未经过 Apple notarization|无许可证|未提供开源许可证' README_ZH.md >/dev/null \
  || fail "README_ZH.md missing notarization or license notice"

grep -Fq 'origin/main' .github/workflows/release.yml \
  || fail "release workflow does not verify tag commit against origin/main"
grep -Fq 'github.ref_name' .github/workflows/release.yml \
  || fail "release workflow does not verify the tag version"
grep -Fq 'VERSION' .github/workflows/release.yml \
  || fail "release workflow does not read VERSION"

search_pattern '#if DEBUG' Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift >/dev/null \
  || fail "WKWebView developer extras are not debug-gated"

echo "release hygiene passed for $CURRENT_TAG"
