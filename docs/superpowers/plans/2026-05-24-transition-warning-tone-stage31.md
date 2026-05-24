# Transition Warning Tone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Demote Program transition controls from warning-orange treatment to neutral configuration styling.

**Architecture:** Keep the existing `ProgramTransitionControlModel` as the source of UI semantics. Add a small equatable tone model and make both Program Monitor and Audio Mixer transition sliders read from it instead of hardcoding `StudioTheme.Tone.warn`.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Model Transition Tone Semantics

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramTransitionControlModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioTransitionControlModelTests.swift`

- [x] **Step 1: Write the failing test**

Add assertions that `ProgramTransitionControlModel` exposes idle status and a neutral action-primary tone.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioTransitionControlModelTests`

Expected: FAIL because the model does not expose the new tone/status properties yet.

- [x] **Step 3: Implement minimal model**

Add `ProgramTransitionControlTone` and model properties for `statusKind` and `controlTone`.

- [x] **Step 4: Run targeted test**

Run: `swift test --filter AudioTransitionControlModelTests`

Expected: PASS.

### Task 2: Wire Views To Neutral Tone

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AudioMixerView.swift`

- [x] **Step 1: Update Program Monitor transition control**

Use `model.controlTone.sliderTint` for the slider and `model.controlTone.valueTint` for the value text.

- [x] **Step 2: Update Audio transition card**

Use the same model tint and `model.statusKind` for the card status.

- [x] **Step 3: Add source assertions**

Extend tests so Program Monitor no longer hardcodes warning tint for transition controls and Audio Mixer uses the model tone.

- [x] **Step 4: Run targeted tests**

Run: `swift test --filter AudioTransitionControlModelTests`

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

Launch the app, capture the Run Desk, and verify the Transition slider is no longer orange warning-styled.

- [ ] **Step 3: Open PR and auto-merge**

Create a PR, wait for CI to pass, then squash merge and delete the branch.
