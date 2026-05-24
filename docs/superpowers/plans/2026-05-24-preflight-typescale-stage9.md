# Preflight TypeScale Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove raw SwiftUI font literals from Preflight/Cockpit review surfaces so their typography follows the shared StudioTheme TypeScale.

**Architecture:** Keep this as a narrow post-refactor convergence PR. Do not change Preflight behavior or layout structure; replace local `.font(.system(size:...))` calls in `PreflightPopoverView` and `SafetyCockpitView` with existing `StudioTheme.TypeScale` tokens and add source hygiene tests.

**Tech Stack:** SwiftUI, SwiftPM, XCTest source hygiene tests.

---

### Task 1: Source Hygiene Test

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PreflightTypographyConvergenceTests.swift`
- Modify: none

- [ ] **Step 1: Write the failing test**

Add tests that load `Views/PreflightPopoverView.swift` and `Views/SafetyCockpitView.swift`, then assert they do not contain `.font(.system(size:`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreflightTypographyConvergenceTests`

Expected: FAIL because both files still contain raw `.font(.system(size:` calls.

### Task 2: Replace Raw Font Literals

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SafetyCockpitView.swift`

- [ ] **Step 1: Replace raw fonts with TypeScale tokens**

Use existing tokens:
- Large title and hero numbers: `StudioTheme.TypeScale.display`
- Section titles and strong labels: `StudioTheme.TypeScale.heading.weight(.black)` or `.weight(.bold)`
- Body rows: `StudioTheme.TypeScale.body` / `.weight(.bold)`
- Help and captions: `StudioTheme.TypeScale.caption`
- Status pills: `StudioTheme.TypeScale.label`
- Monospaced event values: `StudioTheme.TypeScale.mono` / `.weight(.bold)`

- [ ] **Step 2: Run targeted tests**

Run: `swift test --filter PreflightTypographyConvergenceTests --filter PreflightReviewModelTests --filter HelpPreflightSplitTests`

Expected: PASS.

### Task 3: Full Verification and PR

**Files:**
- No additional source edits unless verification fails.

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

Commit message: `fix: converge preflight typography tokens`

Acceptance criteria:
- Preflight popover no longer contains raw `.font(.system(size:` calls.
- Safety Cockpit no longer contains raw `.font(.system(size:` calls.
- Preflight/Cockpit behavior and actions remain unchanged.
- Required verification commands pass.
