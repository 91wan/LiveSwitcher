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

require_literal_in_file() {
  local file="$1"
  local literal="$2"
  local label="$3"

  grep -Fq "$literal" "$file" \
    || fail "$file missing $label"
}

derive_previous_version() {
  local versions
  local previous=""
  local version

  versions="$(
    git ls-files 'docs/qa/release-hygiene-v*.md' \
      | sed -n -E 's#.*release-hygiene-v([0-9]+)\.([0-9]+)\.([0-9]+)\.md$#\1 \2 \3#p' \
      | awk '{ printf "%09d.%09d.%09d %d.%d.%d\n", $1, $2, $3, $1, $2, $3 }' \
      | sort \
      | awk '{ print $2 }'
  )"

  while IFS= read -r version; do
    [[ -n "$version" ]] || continue
    if [[ "$version" == "$CURRENT_VERSION" ]]; then
      [[ -n "$previous" ]] || return 1
      printf '%s\n' "$previous"
      return 0
    fi
    previous="$version"
  done <<<"$versions"

  return 1
}

require_package_manifest_sync() {
  require_file Package.swift
  require_file Sources/AnnualMeetingSwitcher/Package.swift

  require_literal_in_file Package.swift 'name: "LiveSwitcher"' "package name"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift 'name: "LiveSwitcher"' "package name"
  require_literal_in_file Package.swift '.macOS("14.0")' "macOS 14 platform"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift '.macOS(.v14)' "macOS 14 platform"
  require_literal_in_file Package.swift 'name: "LiveSwitcher",' "app target"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift 'name: "LiveSwitcher",' "app target"
  require_literal_in_file Package.swift 'path: "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher"' "root app target path"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift 'path: "Sources/AnnualMeetingSwitcher"' "nested app target path"
  require_literal_in_file Package.swift 'name: "LiveSwitcherTests",' "test target"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift 'name: "LiveSwitcherTests",' "test target"
  require_literal_in_file Package.swift 'dependencies: ["LiveSwitcher"]' "test dependency"
  require_literal_in_file Sources/AnnualMeetingSwitcher/Package.swift 'dependencies: ["LiveSwitcher"]' "test dependency"
}

require_file VERSION

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"
CURRENT_TAG="v$CURRENT_VERSION"

require_file README.md
require_file README_ZH.md
require_file docs/assets/readme/preview-switch.png
require_file docs/assets/readme/audio-mixer.png
require_file docs/assets/readme/overlays.png
require_file script/check_workspace_guard.sh
require_file script/test_workspace_guard.sh
require_file "docs/qa/release-hygiene-v$CURRENT_VERSION.md"
require_file "docs/qa/workspace-guard-v$CURRENT_VERSION.md"
require_package_manifest_sync

PREVIOUS_VERSION="$(derive_previous_version)" \
  || fail "could not derive previous release version before $CURRENT_VERSION"
PREVIOUS_TAG="v$PREVIOUS_VERSION"

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
      --exclude=.git \
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
  Sources/AnnualMeetingSwitcher/Sources script/build_and_run.sh Sources/AnnualMeetingSwitcher/build_v33.sh .github \
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
grep -Fq 'swift test --package-path Sources/AnnualMeetingSwitcher' .github/workflows/release.yml \
  || fail "release workflow does not run nested package tests"
grep -Fq 'git diff --check' .github/workflows/release.yml \
  || fail "release workflow does not run whitespace check"
grep -Fq 'PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh' .github/workflows/release.yml \
  || fail "release workflow does not run release hygiene with system PATH"
grep -Fq 'ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_NAME"' .github/workflows/release.yml \
  || fail "release workflow does not package with ditto"
grep -Fq 'shasum -a 256 "$ZIP_NAME" > "$CHECKSUM_NAME"' .github/workflows/release.yml \
  || fail "release workflow does not generate checksum asset"
grep -Fq 'body_path: ${{ steps.version.outputs.RELEASE_NOTES_PATH }}' .github/workflows/release.yml \
  || fail "release workflow does not use release notes file"
grep -Fq 'draft: true' .github/workflows/release.yml \
  || fail "release workflow does not create a draft release"

for tcc_key in \
  NSAccessibilityUsageDescription \
  NSAppleEventsUsageDescription \
  NSCameraUsageDescription \
  NSMicrophoneUsageDescription
do
  require_literal_in_file script/build_and_run.sh "$tcc_key" "$tcc_key"
  require_literal_in_file Sources/AnnualMeetingSwitcher/build_v33.sh "$tcc_key" "$tcc_key"
done

search_pattern '#if DEBUG' Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift >/dev/null \
  || fail "WKWebView developer extras are not debug-gated"

echo "release hygiene passed for $CURRENT_TAG"
