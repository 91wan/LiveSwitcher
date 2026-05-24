# Live BGM Metering Stage 36 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Live mode BGM meter use real `AVAudioPlayer` power readings when available, while clearly marking media/master fallback meters as estimated.

**Architecture:** Keep this PR scoped to the reliable `AVAudioPlayer` path for BGM. `LiveAudioMeterModel` accepts optional realtime dBFS plus a fallback fader estimate; `SwitcherViewModel` publishes the latest BGM average power from the existing BGM progress timer; `LiveAudioStrip` uses realtime BGM dB and keeps media/master on explicit fallback estimates.

**Tech Stack:** Swift, SwiftUI, AVFoundation, XCTest, SwiftPM.

---

### Task 1: Meter Model Semantics

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeRuntimeModels.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`

- [ ] **Step 1: Write failing tests**

Add tests for muted, realtime dB, clipping warning, and fallback-estimated display:

```swift
func testAudioMeterModelUsesRealtimeDBWhenAvailable() {
    let meter = LiveAudioMeterModel.make(realtimeDB: -12, fallbackEffectiveVolume: 1, isMuted: false)
    XCTAssertEqual(meter.decibelText, "-12 dB")
    XCTAssertEqual(meter.statusKind, .ready)
    XCTAssertFalse(meter.isEstimated)
    XCTAssertEqual(meter.level, 0.8, accuracy: 0.01)
}
```

- [ ] **Step 2: Verify the tests fail**

Run:

```bash
swift test --filter LiveModeMixerControlsTests/testAudioMeterModel
```

Expected: compile failure for missing `make(realtimeDB:fallbackEffectiveVolume:isMuted:)` and `isEstimated`.

- [ ] **Step 3: Implement the model**

Add `isEstimated`, dB clamping to `-60...0`, warning for `>= -3 dB`, and fallback text prefixed with `≈`.

- [ ] **Step 4: Verify model tests pass**

Run:

```bash
swift test --filter LiveModeMixerControlsTests/testAudioMeterModel
```

Expected: relevant meter tests pass.

### Task 2: ViewModel BGM Realtime Metering

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`

- [ ] **Step 1: Write failing source-contract test**

Assert `AVAudioPlayer` metering is enabled and average power is sampled from the BGM timer path:

```swift
func testBGMPlayerEnablesRealtimeMetering() throws {
    let source = try sourceText("ViewModel.swift")
    XCTAssertTrue(source.contains("player.isMeteringEnabled = true"))
    XCTAssertTrue(source.contains("averagePower(forChannel: 0)"))
    XCTAssertTrue(source.contains("bgmRealtimeLevelDB"))
}
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
swift test --filter LiveModeMixerControlsTests/testBGMPlayerEnablesRealtimeMetering
```

Expected: failure because the strings are absent.

- [ ] **Step 3: Implement BGM metering**

Add `@Published var bgmRealtimeLevelDB: Float?`, enable `player.isMeteringEnabled = true`, update meters during `updateBGMProgress()`, and clear the realtime value whenever playback stops/fails or the player is removed.

- [ ] **Step 4: Verify the BGM hook test passes**

Run:

```bash
swift test --filter LiveModeMixerControlsTests/testBGMPlayerEnablesRealtimeMetering
```

Expected: pass.

### Task 3: Live Audio Strip Wiring

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`

- [ ] **Step 1: Write failing source test**

Assert the Live BGM meter uses `bgmRealtimeLevelDB` while media/master use explicit fallback:

```swift
func testLiveAudioStripUsesRealtimeBGMMeter() throws {
    let source = try sourceText("Views/LiveModeView.swift")
    XCTAssertTrue(source.contains("realtimeDB: viewModel.bgmRealtimeLevelDB"))
    XCTAssertTrue(source.contains("fallbackEffectiveVolume: viewModel.effectiveBGMOutputVolume()"))
}
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
swift test --filter LiveModeMixerControlsTests/testLiveAudioStripUsesRealtimeBGMMeter
```

Expected: failure because the view still uses `make(effectiveVolume:isMuted:)` for BGM.

- [ ] **Step 3: Wire the view**

Call the new model API for all meters. Pass `bgmRealtimeLevelDB` only for BGM. Include `!viewModel.isBGMPlaying` in the BGM muted condition so stopped BGM does not show a stale meter.

- [ ] **Step 4: Verify targeted tests pass**

Run:

```bash
swift test --filter LiveModeMixerControlsTests
```

Expected: all Live mode mixer tests pass.

### Task 4: Full Verification and PR

**Files:**
- No production files unless verification finds a bug.

- [ ] **Step 1: Run full local verification**

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

- [ ] **Step 2: Screenshot acceptance**

Open the app and capture Live mode after the change. Confirm the BGM meter remains visible and the UI is not regressed.

- [ ] **Step 3: Create PR**

Commit and open a PR titled:

```text
fix: meter live BGM from player audio power
```

- [ ] **Step 4: CI and merge**

Watch GitHub checks. If they pass, squash-merge and delete the branch automatically.
