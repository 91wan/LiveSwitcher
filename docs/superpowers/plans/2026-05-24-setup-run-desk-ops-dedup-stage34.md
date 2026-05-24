# Setup Run Desk Ops Dedup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove duplicated Audio/BGM controls from the Setup Run Desk right rail while keeping projection control and a clear path into Live mode.

**Architecture:** Keep the existing `LiveOpsPanel` ownership for the setup right rail, but reduce it to output/projection plus a compact "Switch to Live" CTA. The Setup audio dock remains the single audio control surface outside the Audio tab.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Add Regression Tests

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RunDeskControlConvergenceTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AccessibilityHiddenContractTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveOpsLayoutMetricsTests.swift`

- [x] **Step 1: Write failing tests**

Add source tests that assert `LiveOpsPanel.swift` no longer contains `audioCard`, `bgmMiniCard`, `BGM progress`, or `Open audio mixer page`, and does contain `Switch to Live` plus an `onSwitchToLive` action.

- [x] **Step 2: Run targeted tests**

Run: `swift test --filter RunDeskControlConvergenceTests`

Expected: FAIL because the setup right rail still renders Audio/BGM cards.

### Task 2: Trim Setup Right Rail

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`

- [x] **Step 1: Replace the mixer callback with a live-mode callback**

Change `LiveOpsPanel` to accept `onSwitchToLive` and wire `ContentView.runDesk()` to set `viewModel.consoleMode = .live`.

- [x] **Step 2: Remove duplicated audio and BGM cards**

Delete `audioCard`, `bgmMiniCard`, mode toggle helpers, and BGM progress helpers from `LiveOpsPanel`.

- [x] **Step 3: Add compact setup live CTA**

Add a secondary card/button labelled `Switch to Live` so setup users can move to the full live control surface.

- [x] **Step 4: Run targeted tests**

Run: `swift test --filter RunDeskControlConvergenceTests`

Expected: PASS.

### Task 3: Verification And PR

**Files:**
- No further source edits expected.

- [x] **Step 1: Full verification**

Run:
`swift build`
`swift test`
`cd Sources/AnnualMeetingSwitcher && swift test`
`git diff --check`
`./script/check_release_hygiene.sh`
`PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
`./script/build_and_run.sh --verify`
`bash Sources/AnnualMeetingSwitcher/build_v33.sh`
`plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
`codesign --verify --deep --strict dist/LiveSwitcher.app`

- [x] **Step 2: Screenshot acceptance**

Launch Setup / Run Desk and capture the main window, verifying the right rail only carries Output plus the Live CTA while the bottom Setup audio dock remains visible.

- [ ] **Step 3: Open PR and auto-merge**

Create a PR, wait for CI to pass, then squash merge and delete the branch.
