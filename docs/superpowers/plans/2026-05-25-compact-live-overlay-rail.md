# Compact Live Overlay Rail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compress the Live mode overlay rail from six controls to three operator-readable rows that show the currently selected preset and expose a single OFF/LIVE action per overlay.

**Architecture:** Add a pure `LiveOverlayRailRowModel` that derives labels, disabled state, and accessibility text from existing preset arrays and selected IDs. `LiveModeView` keeps the existing preset persistence and send-live APIs, but renders each overlay as one compact row with a preset menu region and a right-side state action.

**Tech Stack:** SwiftPM macOS app, SwiftUI, XCTest source/model tests.

---

### Task 1: Model Current Overlay Preset Labels

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveOverlayRailRowModel.swift`
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveOverlayRailRowModelTests.swift`

- [ ] **Step 1: Write failing model tests**

Test empty, selected, countdown formatted, and long ticker labels:

```swift
func testEmptyLowerThirdUsesNewPresetCopyAndDisablesToggle() {
    let model = LiveOverlayRailRowModel.lowerThird(presets: [], selectedID: nil, isLive: false)
    XCTAssertEqual(model.presetLabel, "+ New preset")
    XCTAssertFalse(model.canToggle)
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter LiveOverlayRailRowModelTests`
Expected: FAIL because `LiveOverlayRailRowModel` does not exist.

- [ ] **Step 3: Add model implementation**

Implement static constructors for lower third, countdown, and ticker using existing preset types. Keep label truncation deterministic and ASCII-safe except for existing user content.

- [ ] **Step 4: Run focused tests**

Run: `swift test --filter LiveOverlayRailRowModelTests`
Expected: PASS.

### Task 2: Replace Two-Line Overlay Controls With Compact Rows

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [ ] **Step 1: Add source-level regression test**

Assert `LiveModeView` uses `compactOverlayRow`, no longer calls standalone `lowerThirdPresetMenu`, `countdownPresetMenu`, or `tickerPresetMenu`, and still calls `showLowerThirdPreset`, `startCountdownPreset`, and `startTickerPreset`.

- [ ] **Step 2: Run test to verify failure**

Run: `swift test --filter LiveModeLayoutTests/testLiveOverlayRailUsesCompactPresetRows`
Expected: FAIL before the view is refactored.

- [ ] **Step 3: Refactor overlay card**

Render three rows. The left/middle area is a menu or setup button. The right chip toggles live state and is disabled until a preset is selected. Preserve Setup navigation for empty libraries.

- [ ] **Step 4: Run focused layout/model tests**

Run: `swift test --filter LiveModeLayoutTests --filter LiveOverlayRailRowModelTests`
Expected: PASS.

### Task 3: Verify and Publish PR

**Files:**
- No additional source changes unless verification finds regressions.

- [ ] **Step 1: Run full local verification**

Run the required LiveSwitcher chain: `swift build`, `swift test`, nested `swift test`, `git diff --check`, both release hygiene commands, `./script/build_and_run.sh --verify`, `bash Sources/AnnualMeetingSwitcher/build_v33.sh`, `plutil`, and `codesign`.

- [ ] **Step 2: Screenshot acceptance**

Launch the app and capture Live mode; verify Overlays now has three compact rows and no clipped text at the minimum window size.

- [ ] **Step 3: Commit, push, open PR, wait for CI, merge**

Use branch `codex/compact-live-overlay-rail`, title `fix: compact live overlay rail`, and include tests and screenshot path in the PR body.
