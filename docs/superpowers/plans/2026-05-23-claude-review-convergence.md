# Claude Review Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the remaining Claude deep-review runtime correctness items as a sequence of small, testable PRs.

**Architecture:** Keep each PR centered on one runtime seam: automation observability, display selection/window sync, page-intercept telemetry/performance, build hygiene, then lower-risk state hardening. Prefer pure helpers and model tests before wiring them into SwiftUI/AppKit surfaces.

**Tech Stack:** Swift 5.9, SwiftPM macOS executable, XCTest, AppKit, OSLog.

---

## PR 1: AppleScript Failure Observability

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/AppleScriptRunner.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/KeynoteController.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/LiveSwitcherTelemetry.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveSupportReport.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AppleScriptRunnerTests.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveSupportReportPrivacyTests.swift`

- [ ] Write failing tests for malformed AppleScript compile errors and support-report retention of `applescript.failed`.
- [ ] Add `AppleScriptError` and `AppleScriptRunner.run(_:, action:)`.
- [ ] Route `KeynoteController.runAppleScript` through the shared runner.
- [ ] Replace direct `NSAppleScript` execution in `SwitcherViewModel` with the runner and sanitized support events.
- [ ] Add explicit operator alert hooks for Keynote/WPS automation failure without changing playback/projection behavior.
- [ ] Run targeted tests, full SwiftPM tests, hygiene checks, package smoke, open PR, watch CI, merge after green.

**Verification:** `swift test --filter AppleScriptRunnerTests`, `swift test --filter LiveSupportReportPrivacyTests`, then the full required command chain.

**Acceptance:** No silent `NSAppleScript` execution remains in `SwitcherViewModel`; failures emit telemetry and support events; WPS fallback failure is observable to the operator.

## PR 2: Screen Selection And Output Frame Recheck

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/ScreenSelectionPolicy.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SettingsView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ScreenSelectionPolicyTests.swift`

- [ ] Write failing tests for pinned screen, closest-1080p fallback, and non-main fallback.
- [ ] Add a default screen policy using non-main candidates and optional pinned localized name.
- [ ] Make `SecondScreenSelector` delegate to the policy while preserving `externalScreenProvider` test injection.
- [ ] Recheck current external screen in each async `OutputWindowController.show` frame sync branch.
- [ ] Add a small Settings pin control without changing projection behavior.
- [ ] Run verification, PR, CI, merge.

**Verification:** policy tests, output/projection smoke tests, full required command chain.

**Acceptance:** Multi-display selection is deterministic and async frame correction never uses a stale screen snapshot after display changes.

## PR 3: Page Intercept Logging, WPS PID Cache, And Support Events

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/WPSApplicationMonitor.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/AVPlayerCoordinator.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/LiveSwitcherTelemetry.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveSupportReport.swift`
- Test: targeted runtime/support-event tests.

- [ ] Write failing tests for page-intercept support event kinds and WPS PID cache state transitions.
- [ ] Replace remaining `print(...)` calls with `LiveSwitcherTelemetry`.
- [ ] Record page intercept enabled/disabled/forwarded/WPS-not-running, system-volume-sync, and playback-ended events.
- [ ] Move WPS running-app lookup out of the CG tap path with a cached monitor.
- [ ] Run verification, PR, CI, merge.

**Verification:** runtime support-event tests, smoke tests, full required command chain.

**Acceptance:** No release `print(...)` remains in app code; support reports show high-signal runtime transitions; tap callback avoids launch-services scanning.

## PR 4: Build And Release Hygiene Convergence

**Files:**
- Modify: `script/check_release_hygiene.sh`
- Modify: `script/build_and_run.sh`
- Modify: `Sources/AnnualMeetingSwitcher/build_v33.sh`
- Create or modify: script/tests for package and plist hygiene.

- [ ] Add tests or script checks that root and nested `Package.swift` stay synchronized.
- [ ] Derive previous release version from tags or release hygiene docs instead of a hardcoded string.
- [ ] Synchronize Info.plist usage descriptions across build scripts, including Accessibility and Camera keys.
- [ ] Run verification, PR, CI, merge.

**Verification:** hygiene script normal and fallback PATH modes, build bundle smoke, Info.plist lint, codesign verify.

**Acceptance:** Release checks do not rely on stale hand-edited previous-version constants, and generated app bundles have consistent TCC descriptions.

## PR 5: Runtime State Hardening Follow-Up

**Files:**
- Modify focused model/engine files for `AudioStrategy`, missing-file reporting, wallpaper content-type checks, output display state, media routing start timing, and projection cache.
- Test: focused model and ViewModel tests per item.

- [ ] Convert `AudioStrategy` persistence to stable ASCII slugs with migration from legacy Chinese values.
- [ ] Record missing restored BGM/program files for preflight/support visibility.
- [ ] Use URL content type when validating wallpapers, with extension fallback.
- [ ] Reduce output-view over-observation through a lightweight display state if tests show churn risk.
- [ ] Remove transient media mute on switch-to-media by reordering or guarding routing.
- [ ] Cache external-display availability at the ViewModel boundary.
- [ ] Run verification, PR, CI, merge.

**Verification:** focused tests per behavior, full required command chain.

**Acceptance:** Lower-risk review items are closed without broad UI redesign or core playback/projection/audio route changes.
