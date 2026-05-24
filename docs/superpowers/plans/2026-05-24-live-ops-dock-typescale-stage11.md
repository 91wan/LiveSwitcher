# Live Ops Dock TypeScale Convergence Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Continue Round 3 N6 typography convergence on the always-visible live operations controls.

**Scope:** Replace raw `.font(.system(size: ...))` calls in `LiveOpsPanel.swift` and `SetupAudioDock.swift` with existing `StudioTheme.TypeScale` tokens. Keep behavior, layout structure, controls, colors, and runtime logic unchanged.

---

### Task 1: Source Hygiene Test

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveOpsDockTypographyConvergenceTests.swift`

- [ ] Assert `Views/LiveOpsPanel.swift` has no `.font(.system(size:` calls and uses `StudioTheme.TypeScale`.
- [ ] Assert `Views/SetupAudioDock.swift` has no `.font(.system(size:` calls and uses `StudioTheme.TypeScale`.
- [ ] Run `swift test --filter LiveOpsDockTypographyConvergenceTests` and confirm it fails before implementation.

### Task 2: Replace Raw Font Literals

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SetupAudioDock.swift`

- [ ] Use `StudioTheme.TypeScale.body` for live action labels and titles.
- [ ] Use `StudioTheme.TypeScale.caption` for compact controls.
- [ ] Use `StudioTheme.TypeScale.label` for rounded status/count text.
- [ ] Do not alter control sizes, card metrics, or routing/playback behavior.

### Task 3: Verification and PR

- [ ] Run targeted tests:
  - `swift test --filter LiveOpsDockTypographyConvergenceTests --filter LiveOpsLayoutMetricsTests --filter SetupAudioDockModelTests`
- [ ] Run required local gates:
  - `swift build`
  - `swift test`
  - `cd Sources/AnnualMeetingSwitcher && swift test`
  - `git diff --check`
  - `./script/check_release_hygiene.sh`
  - `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
  - `./script/build_and_run.sh --verify`
  - screenshot the LiveSwitcher window
  - `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
  - `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
  - `codesign --verify --deep --strict dist/LiveSwitcher.app`
- [ ] Commit, open PR, wait for CI, and merge when green.

Acceptance criteria:
- `LiveOpsPanel.swift` and `SetupAudioDock.swift` no longer contain raw `.font(.system(size:` calls.
- Existing live ops and setup dock tests continue to pass.
- No new dependency or VERSION change.
