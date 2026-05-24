# Lower Third Presets Stage 39 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let operators prepare multiple lower-third cards in Setup and trigger a selected card directly from Live mode.

**Architecture:** Add a Codable `LowerThirdPreset` model and persist it through the existing `SwitcherViewModel.saveData/loadData` path. Setup Overlay Composer gains a compact lower-third preset shelf for New / Save / Delete / Load. Live mode gains a preset menu that sends the selected preset live through the existing `showLowerThird(name:title:)` path.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Preset Model and ViewModel API

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LowerThirdPreset.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Overlay.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LowerThirdPresetTests.swift`

- [x] **Step 1: Write failing tests**

Cover trimmed preset creation, empty name rejection, ViewModel save/load, loading a preset into the composer draft, and sending a preset live.

- [x] **Step 2: Verify tests fail**

Run:

```bash
swift test --filter LowerThirdPresetTests
```

Expected: compile failure because `LowerThirdPreset` and ViewModel preset APIs do not exist.

- [x] **Step 3: Implement model and ViewModel API**

Add `lowerThirdPresets`, JSON persistence, and methods to save/load/delete/send presets.

- [x] **Step 4: Verify model tests pass**

Run:

```bash
swift test --filter LowerThirdPresetTests
```

Expected: tests pass.

### Task 2: Setup and Live UI Wiring

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/OverlayLivePreviewModelTests.swift`

- [x] **Step 1: Write failing source contract tests**

Assert Setup overlays expose lower-third preset controls, and Live overlays can send a selected lower-third preset directly.

- [x] **Step 2: Verify source tests fail**

Run:

```bash
swift test --filter LiveModeLayoutTests/testLiveLowerThirdPresetMenuSendsSelectedPresetDirectly
swift test --filter OverlayLivePreviewModelTests/testOverlayComposerExposesLowerThirdPresetShelf
```

Expected: failure because no preset controls exist.

- [x] **Step 3: Implement UI wiring**

Add Setup preset shelf and Live preset menu. Keep the existing draft send path as a temporary one-off path.

- [x] **Step 4: Verify targeted UI tests pass**

Run the same two filtered tests plus `LowerThirdPresetTests`.

### Task 3: Full Verification and PR

- [x] **Step 1: Run full local verification**

Run:

```bash
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
git diff --check
./script/check_release_hygiene.sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh
./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint dist/LiveSwitcher.app/Contents/Info.plist
codesign --verify --deep --strict dist/LiveSwitcher.app
```

- [x] **Step 2: Screenshot acceptance**

Capture Setup Overlays with lower-third preset shelf and Live mode with the lower-third preset menu visible or at least the compact preset entry.

- [ ] **Step 3: Create PR**

Commit and open:

```text
fix: add lower third presets for live mode
```

- [ ] **Step 4: CI and merge**

Watch checks and squash-merge automatically when green.
