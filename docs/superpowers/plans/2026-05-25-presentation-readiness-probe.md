# Presentation Readiness Probe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PPTX/Keynote readiness visible before operators put a presentation on screen.

**Architecture:** Add a read-only `PresentationReadinessProbe` with injectable environment for tests and live NSWorkspace/TCC checks in production. Render a small status dot and queue summary in Setup and Live source rails, and gate blocked presentation selection with an explicit confirmation.

**Tech Stack:** SwiftPM macOS app, Swift/AppKit/ApplicationServices/SwiftUI, XCTest.

---

### Task 1: Readiness Engine

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/PresentationReadinessProbe.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PresentationReadinessProbeTests.swift`

- [x] Write failing tests for non-presentation items, missing Keynote, missing WPS with Keynote fallback, broken file URL, permission denied, ready states, and summary counts.
- [x] Run `swift test --filter PresentationReadinessProbeTests` and verify failures because the probe is missing.
- [x] Implement `PresentationReadinessProbe`, `PresentationReadinessResult`, `PresentationReadinessEnvironment`, `PresentationAutomationPermission`, and `PresentationReadinessSummary`.
- [x] Re-run focused tests and verify green.

### Task 2: Queue And Live Indicators

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PresentationReadinessDot.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PresentationReadinessProbeTests.swift`

- [x] Add source-level tests that Run Queue rows and Live source rail rows render `PresentationReadinessDot`, and LeftPanel renders `PresentationReadinessSummary`.
- [x] Run focused tests and verify failures.
- [x] Add the shared readiness dot view and wire it into `SignalSourceRow` and `LiveSourceRailRow`.
- [x] Add a compact summary row above the Run Queue import area.
- [x] Re-run focused tests and verify green.

### Task 3: Blocked Presentation Confirmation

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PresentationReadinessProbeTests.swift`

- [x] Add source-level tests that row selection calls `switchToProgramAfterReadinessConfirmation`.
- [x] Run focused tests and verify failures.
- [x] Add a ViewModel helper that shows a compact NSAlert only for blocked presentation results, then calls the existing `switchToProgram`.
- [x] Re-run focused tests and verify green.

### Task 4: Full Verification And PR

- [x] Run `swift build`.
- [x] Run `swift test`.
- [x] Run `cd Sources/AnnualMeetingSwitcher && swift test`.
- [x] Run `git diff --check`.
- [x] Run `./script/check_release_hygiene.sh`.
- [x] Run `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`.
- [x] Run `./script/build_and_run.sh --verify`.
- [x] Run `bash Sources/AnnualMeetingSwitcher/build_v33.sh`.
- [x] Run `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`.
- [x] Run `codesign --verify --deep --strict dist/LiveSwitcher.app`.
- [x] Use Computer Use screenshot/app-tree acceptance on Setup Run and Live mode to verify readiness indicators do not crowd the rails.
- [ ] Commit, open PR, wait for GitHub CI, and squash merge when green.

## Acceptance
- PPTX/Keynote/active deck rows expose ready/warn/blocked status without launching presentation apps.
- Missing app and missing file states are visibly blocked.
- Automation permission issues are visibly warning/blocking with an operator-readable reason.
- Run Queue has a compact readiness summary.
- Live source rail has the same readiness signal.
- Blocked presentation items require explicit confirmation before switching.
- Existing presentation playback scripts are not modified.
