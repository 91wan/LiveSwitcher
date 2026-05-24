# Live Overlay Action Targets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure Live mode overlay quick actions use a minimum operator-safe hit target.

**Architecture:** Centralize the Live quick action row height in `LiveModeLayoutMetrics`, then bind the overlay action rows to that metric instead of a magic 30pt frame.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Protect The Metric

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeLayoutMetrics.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [x] **Step 1: Write the failing test**

Add assertions that `LiveModeLayoutMetrics.quickActionButtonHeight >= 34` and that `LiveModeView` uses the metric for overlay quick action rows.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter LiveModeLayoutTests`

Expected: FAIL because the metric does not exist yet.

- [x] **Step 3: Add the metric**

Define `quickActionButtonHeight` in `LiveModeLayoutMetrics`.

- [x] **Step 4: Run targeted test**

Run: `swift test --filter LiveModeLayoutTests`

Expected: The source assertion may still fail until the view is wired.

### Task 2: Wire Live Overlay Rows

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`

- [x] **Step 1: Replace hardcoded 30pt row height**

Change `.frame(height: 30)` in `overlayButton` to `.frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)`.

- [x] **Step 2: Run targeted test**

Run: `swift test --filter LiveModeLayoutTests`

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

Launch Live mode and capture the main window, verifying overlay quick action rows remain visible and use the larger target height.

- [ ] **Step 3: Open PR and auto-merge**

Create a PR, wait for CI to pass, then squash merge and delete the branch.
