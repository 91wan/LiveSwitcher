# Live Audio Panic BGM Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair runtime audio routing, Live speaker mode, Panic playback freezing, BGM transitions, and the most obvious UI invalidation hotspots without changing product direction.

**Architecture:** Keep the existing SwiftPM macOS app structure. Fix pure routing semantics first, then use ViewModel smoke tests for side-effect paths that must update player volumes and playback state. Avoid UI redesign; UI changes are limited to calling the correct ViewModel actions and clarifying strategy/limiter text.

**Tech Stack:** Swift, SwiftPM, SwiftUI, AVFoundation, XCTest.

---

### Task 1: Audio Routing Strategy Semantics

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/AudioRoutingEngine.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRoutingEngineTests.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift`

- [ ] Write failing tests that prove `mixed`, `followProgram`, `followSource`, and `bgmOnly` affect effective media/BGM output while BGM is playing.
- [ ] Run the targeted tests and confirm they fail because BGM playback currently acts like implicit takeover.
- [ ] Change routing so BGM playback is not automatically a takeover limiter; only explicit takeover limits media.
- [ ] Run targeted routing and ViewModel smoke tests.

### Task 2: Live Speaker Toggle Side Effects

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift`

- [ ] Write failing source-hygiene and smoke tests showing Live Mode cannot bind directly to `$viewModel.isSpeakerMode`.
- [ ] Replace the direct binding with a binding that calls `toggleSpeakerMode()`.
- [ ] Run targeted Live mode and speaker smoke tests.

### Task 3: Panic Freezes Current Media

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift`

- [ ] Write failing tests for Panic pausing playing media, not auto-playing previously paused media, not restoring after a program change, and keeping FTB visual-only.
- [ ] Add a small Panic playback snapshot to the ViewModel.
- [ ] Pause media on Panic activation and resume only when the same media item was playing before Panic.
- [ ] Run targeted Panic tests.

### Task 4: BGM Transition Ownership

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SwitcherViewModelSmokeTests.swift`

- [ ] Write failing tests showing next/previous BGM does not immediately stop and nil the current player before fade-out.
- [ ] Add a single BGM transition task owner and helper methods for fade-out, start-at-zero, and release-after-fade.
- [ ] Use the helper from stop/current/next/previous paths and cancel stale transitions on rapid switches.
- [ ] Run targeted BGM transition tests.

### Task 5: Focused Runtime Smoothness Fixes

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeStateHardeningTests.swift`

- [ ] Write source-hygiene tests for obvious synchronous image loading and high-frequency ViewModel publishing risks.
- [ ] Move synchronous wallpaper/logo image loading out of property observers or document and constrain any remaining exceptions.
- [ ] Keep changes small enough for this bug-fix PR.
- [ ] Run targeted runtime hardening tests.

### Task 6: Verification and PR

**Files:**
- No production files unless verification reveals a bug.

- [ ] Run `swift build`.
- [ ] Run `swift test`.
- [ ] Run `cd Sources/AnnualMeetingSwitcher && swift test`.
- [ ] Run `git diff --check`.
- [ ] Run both release hygiene commands.
- [ ] Run `./script/build_and_run.sh --verify`.
- [ ] Run release packaging, plist lint, and codesign verify.
- [ ] Capture/inspect changed app screens if UI-visible state changed.
- [ ] Open PR, wait for CI, and squash merge when green.
