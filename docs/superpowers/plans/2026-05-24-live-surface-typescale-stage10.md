# Live Surface TypeScale Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Continue the Round 3 N6 typography convergence by moving the main live/run control surfaces off raw SwiftUI font literals.

**Architecture:** Keep this PR source-only and behavior-neutral. Replace `.font(.system(size:...))` in `RunQueueView`, `LiveModeView`, and `MainToolbar` with existing `StudioTheme.TypeScale` tokens, adding only tiny TypeScale support if an existing token is missing.

**Tech Stack:** SwiftUI, SwiftPM, XCTest source hygiene tests.

---

### Task 1: Source Hygiene Test

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveSurfaceTypographyConvergenceTests.swift`

- [ ] **Step 1: Write the failing test**

Assert these files no longer contain `.font(.system(size:`:
- `Views/RunQueueView.swift`
- `Views/LiveModeView.swift`
- `Views/MainToolbar.swift`

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LiveSurfaceTypographyConvergenceTests`

Expected: FAIL because all three files still contain raw font literals.

### Task 2: Replace Raw Font Literals

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift`

- [ ] **Step 1: Replace raw fonts with TypeScale tokens**

Use:
- `StudioTheme.TypeScale.heading.weight(...)` for strong section/action titles
- `StudioTheme.TypeScale.body.weight(...)` for row titles
- `StudioTheme.TypeScale.caption.weight(...)` for compact action text
- `StudioTheme.TypeScale.label` for status/count badges
- `StudioTheme.TypeScale.monoCaption` for compact monospaced timers

- [ ] **Step 2: Run targeted tests**

Run: `swift test --filter LiveSurfaceTypographyConvergenceTests --filter LiveModeLayoutTests --filter RunDeskControlConvergenceTests --filter TopChromeConvergenceTests`

Expected: PASS.

### Task 3: Full Verification and PR

- [ ] **Step 1: Run required local gates**

Run:
- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- capture a LiveSwitcher window screenshot
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

- [ ] **Step 2: Commit, open PR, wait for CI, merge when green**

Commit message: `fix: converge live surface typography tokens`

Acceptance criteria:
- Run queue, live mode, and top toolbar no longer contain raw `.font(.system(size:` calls.
- Runtime behavior is unchanged.
- Required local and CI checks pass.
