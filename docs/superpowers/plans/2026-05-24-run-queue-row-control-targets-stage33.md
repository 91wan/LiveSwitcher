# Run Queue Row Control Targets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Protect Run Queue row transport/delete controls from regressing to undersized 30pt hit targets.

**Architecture:** Add a small `RunQueueLayoutMetrics` model for queue row control sizing, wire `SignalSourceRow.controlButton` to it, and add source/metric tests.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Add The Regression Tests

**Files:**
- Add: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RunQueueLayoutMetricsTests.swift`

- [x] **Step 1: Write failing tests**

Assert `RunQueueLayoutMetrics.rowControlButtonSize >= 34`, `RunQueueView.swift` uses the metric for row control frames, and no longer hardcodes `.frame(width: 30, height: 30)`.

- [x] **Step 2: Run targeted tests**

Run: `swift test --filter RunQueueLayoutMetricsTests`

Expected: FAIL because `RunQueueLayoutMetrics` does not exist yet.

### Task 2: Wire The Metric

**Files:**
- Add: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/RunQueueLayoutMetrics.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift`

- [x] **Step 1: Add `RunQueueLayoutMetrics.rowControlButtonSize`**

Define the row control button size at 34pt.

- [x] **Step 2: Replace the hardcoded control frame**

Update `SignalSourceRow.controlButton` to use `RunQueueLayoutMetrics.rowControlButtonSize`.

- [x] **Step 3: Run targeted tests**

Run: `swift test --filter RunQueueLayoutMetricsTests`

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

Launch Setup / Run Desk and capture the main window, verifying the queue controls remain visually contained at 1360px width.

- [ ] **Step 3: Open PR and auto-merge**

Create a PR, wait for CI to pass, then squash merge and delete the branch.
