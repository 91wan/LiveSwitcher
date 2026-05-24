# Live Mode Runtime Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge Live mode runtime semantics so the status bar shows all important exceptions, source empty state has an action path, FTB no longer aliases Panic, subtitle copy is consistent, and first launch stays dark.

**Architecture:** Keep the existing Live mode layout. Add small runtime models/helpers where the state is currently encoded directly in SwiftUI.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Add Regression Tests

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`
- Add: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ConsoleThemeDefaultTests.swift`

- [x] **Step 1: Write failing tests**

Cover multi-chip runtime status output, source empty-state setup CTA, FTB not calling Panic, subtitle copy cleanup, and first-launch dark theme.

- [x] **Step 2: Run targeted tests**

Run:
`swift test --filter LiveModeMixerControlsTests`
`swift test --filter LiveModeLayoutTests`
`swift test --filter ConsoleThemeDefaultTests`

Expected: FAIL until production code is updated.

### Task 2: Implement Live Runtime Semantics

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeRuntimeModels.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift`

- [x] **Step 1: Replace single runtime status with chip array**

Return up to three fail chips, up to three warn chips, plus a runtime summary chip.

- [x] **Step 2: Add Live source empty-state CTA**

Add `Switch to Setup`, wired to `consoleMode = .setup` and `selectedMainTab = .preview`.

- [x] **Step 3: Add real FTB state**

Add `isFadeToBlackActive`, `toggleFadeToBlack()`, wire Cut Bus FTB to it, and render a black overlay on output without muting audio.

- [x] **Step 4: Clean subtitle copy and dark default test**

Make Audio and Overlay subtitles English-only while preserving bilingual titles, and lock first-launch dark theme behavior.

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

Capture Live mode with empty sources and verify the status chip row plus `Switch to Setup` CTA render without overlap.

- [ ] **Step 3: Open PR and auto-merge**

Create a PR, wait for CI to pass, then squash merge and delete the branch.
