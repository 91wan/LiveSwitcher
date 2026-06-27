#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dev}"

MAX_TOP_LEVEL_VIEW_LINES=300
MAX_FOCUSED_SUBVIEW_LINES=250
MAX_MODEL_REDUCER_LINES=400
MAX_TEST_HELPER_LINES=250
MAX_TEST_FILE_LINES=500
MAX_SOURCE_CONTAINS_PER_TEST_FILE=15

fail() {
  echo "complexity budget failed: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 [--dev|--release]" >&2
}

case "$MODE" in
  --dev|dev)
    MODE="dev"
    ;;
  --release|release)
    MODE="release"
    ;;
  *)
    usage
    exit 2
    ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

violations=0

line_count() {
  wc -l < "$1" | tr -d ' '
}

source_contains_count() {
  awk 'index($0, "source.contains") { count++ } END { print count + 0 }' "$1"
}

record_violation() {
  local category="$1"
  local path="$2"
  local actual="$3"
  local limit="$4"

  printf '  %s: %s has %s, limit %s\n' "$category" "$path" "$actual" "$limit" >&2
  violations=1
}

allow_over_budget_reason() {
  local category="$1"
  local path="$2"

  awk -F '|' -v category="$category" -v path="$path" '
    $1 == category && $2 == path {
      print $3
      found = 1
    }
    END { exit found ? 0 : 1 }
  ' <<'ALLOWLIST'
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift|legacy app shell and window composition; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift|legacy AppKit output-window bridge; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/BGMPlaylistPanel.swift|legacy setup BGM panel; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift|legacy setup navigation panel; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LowerThirdOverlay.swift|legacy overlay renderer; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift|legacy overlay editor panel; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift|legacy preflight popover; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SafetyCockpitView.swift|legacy safety cockpit surface; split planned separately
top-level-view|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift|theme token registry, not a runtime surface; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LivePreflight.swift|broad preflight model aggregation; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift|central BGM runtime reducer; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift|central runtime reducer; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift|central runtime state model; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift|legacy BGM playback facade wiring; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Overlay.swift|legacy overlay facade wiring; split planned separately
model-reducer|Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift|legacy root view model shell; split planned separately
test-file|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeOwnershipTests.swift|legacy runtime ownership matrix; split planned separately
test-file|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/BGMRuntimeReducerBehaviorTests.swift|central BGM reducer behavior matrix; split planned separately
test-file|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LivePreflightTests.swift|broad preflight behavior suite; split planned separately
test-file|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentStateRuntimeLoadBoundaryTests.swift|legacy persistence load boundary matrix; split planned separately
test-file|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift|legacy integration smoke suite; split planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AppLaunchPolicyTests.swift|legacy launch source-contract coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeReducerExtractionTests.swift|runtime reducer extraction contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/BGMPlaylistPanelStaticTests.swift|legacy static BGM panel coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/BGMRuntimeReducerExtractionTests.swift|runtime reducer extraction contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveBGMChooserViewTests.swift|legacy live chooser static coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift|legacy live layout source-contract coverage; replacement in progress
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift|legacy mixer source-contract coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/MediaRuntimeReducerExtractionTests.swift|runtime reducer extraction contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/OverlayLivePreviewModelTests.swift|legacy overlay static coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentStateRuntimeLoadBoundaryTests.swift|legacy persistence source-contract coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PreferencesRuntimeReducerExtractionTests.swift|runtime reducer extraction contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PresentationQueryRuntimeReducerExtractionTests.swift|runtime reducer extraction contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ProgramActivationSideEffectBoundaryTests.swift|side-effect boundary contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ProgramActivationSideEffectWiringTests.swift|side-effect wiring contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RunDeskControlConvergenceTests.swift|legacy run-desk convergence coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeEffectInfrastructureSplitTests.swift|runtime effect split contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/VideoLayerVisibilityTests.swift|legacy video-layer source-contract coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelActionHandlerWiringTests.swift|legacy action-handler wiring contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelEncapsulationTests.swift|legacy view-model encapsulation contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelLiveOutputEncapsulationTests.swift|legacy live-output source-contract coverage; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelMainHygieneTests.swift|legacy view-model hygiene contract; replacement planned separately
source-contains|Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelPersistenceFacadeTests.swift|legacy persistence facade contract; replacement planned separately
ALLOWLIST
}

check_budget() {
  local category="$1"
  local path="$2"
  local actual="$3"
  local limit="$4"
  local reason

  if (( actual <= limit )); then
    return 0
  fi

  if reason="$(allow_over_budget_reason "$category" "$path")"; then
    [[ -n "$reason" ]] || record_violation "$category allowlist reason" "$path" 0 "non-empty reason"
    return 0
  fi

  record_violation "$category" "$path" "$actual" "$limit"
}

is_focused_subview_file() {
  case "$1" in
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveAudioStrip.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveProgramStack.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail+BGM.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail+Overlays.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveRuntimeStatusBar.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveWallpaperPickerThumb.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_top_level_view_file() {
  case "$1" in
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_model_reducer_file() {
  case "$1" in
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel*.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_test_helper_file() {
  case "$1" in
    Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeTestFactory.swift|\
    Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/TestSourceTextSupport.swift|\
    Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ViewModelRuntimeExtractionTestSupport.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while IFS= read -r path; do
  lines="$(line_count "$path")"

  if is_focused_subview_file "$path"; then
    check_budget "focused-subview" "$path" "$lines" "$MAX_FOCUSED_SUBVIEW_LINES"
  elif is_top_level_view_file "$path"; then
    check_budget "top-level-view" "$path" "$lines" "$MAX_TOP_LEVEL_VIEW_LINES"
  elif is_model_reducer_file "$path"; then
    check_budget "model-reducer" "$path" "$lines" "$MAX_MODEL_REDUCER_LINES"
  fi

  if [[ "$path" == Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/*.swift ]]; then
    if is_test_helper_file "$path"; then
      check_budget "test-helper" "$path" "$lines" "$MAX_TEST_HELPER_LINES"
    else
      check_budget "test-file" "$path" "$lines" "$MAX_TEST_FILE_LINES"
    fi

    source_contains="$(source_contains_count "$path")"
    check_budget "source-contains" "$path" "$source_contains" "$MAX_SOURCE_CONTAINS_PER_TEST_FILE"
  fi
done < <(git ls-files '*.swift')

if (( violations != 0 )); then
  fail "one or more files exceed the post-stable complexity budget"
fi

echo "complexity budget passed ($MODE)"
