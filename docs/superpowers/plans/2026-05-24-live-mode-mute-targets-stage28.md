# Live Mode Mute Hit Target Implementation Plan

**Goal:** Keep Live mode mixer mute controls large enough for operator use by avoiding 22pt button targets.

**Scope:** One Live mode view target-size cleanup plus static coverage. No audio routing or mute behavior changes.

---

### Task 1: Use Shared Transport Button Target For Live Mixer Mutes

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`

- [x] **Step 1: Write failing static test**

Assert Live mode no longer contains a `height: 22` mute button and uses `LiveModeLayoutMetrics.transportButtonSize`.

- [x] **Step 2: Verify RED**

Run: `swift test --filter LiveModeMixerControlsTests/testLiveModeMuteButtonsUseTransportHitTargetHeight`

- [x] **Step 3: Implement minimal hit-target cleanup**

Change the Live mixer mute button frame height to `LiveModeLayoutMetrics.transportButtonSize`.

- [x] **Step 4: Verify GREEN**

Run the targeted test again.

- [x] **Step 5: Full verification and screenshot**

Run the standard verification chain and capture Live mode to confirm layout remains usable.
