# Live BGM Picker Stage 37 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let operators choose a specific BGM track directly from Live mode without switching back to Setup Audio.

**Architecture:** Reuse existing `BGMItem` and `BGMCategory` library data. Add a pure `LiveBGMQuickPickerModel` that groups tracks by category for a compact Live menu, then wire the Live BGM card to call the existing `viewModel.toggleBGM(_:)` path when an item is selected.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Live BGM Picker Model

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveBGMQuickPickerModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveBGMQuickPickerModelTests.swift`

- [x] **Step 1: Write failing model tests**

Cover empty library, category grouping, and selected current item:

```swift
func testPickerGroupsTracksByCategory() {
    let warm = BGMItem(title: "Warm", url: URL(fileURLWithPath: "/tmp/warm.mp3"), category: .warmUp)
    let award = BGMItem(title: "Award", url: URL(fileURLWithPath: "/tmp/award.mp3"), category: .award)
    let model = LiveBGMQuickPickerModel.make(items: [warm, award], currentItem: award)

    XCTAssertFalse(model.isLibraryEmpty)
    XCTAssertEqual(model.currentTitle, "Award")
    XCTAssertEqual(model.nonEmptySections.map(\.category), [.warmUp, .award])
}
```

- [x] **Step 2: Verify tests fail**

Run:

```bash
swift test --filter LiveBGMQuickPickerModelTests
```

Expected: compile failure because `LiveBGMQuickPickerModel` does not exist.

- [x] **Step 3: Implement model**

Add a small `Equatable` model with category sections, `currentTitle`, `isLibraryEmpty`, and `nonEmptySections`.

- [x] **Step 4: Verify model tests pass**

Run:

```bash
swift test --filter LiveBGMQuickPickerModelTests
```

Expected: tests pass.

### Task 2: Live BGM Card Menu

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [x] **Step 1: Write failing source contract test**

Assert the Live BGM rail uses the picker model and presents BGM categories/items:

```swift
func testLiveBGMCardOffersLibraryPickerWithoutLeavingLiveMode() throws {
    let source = try sourceText("Views/LiveModeView.swift")
    XCTAssertTrue(source.contains("LiveBGMQuickPickerModel.make"))
    XCTAssertTrue(source.contains("Choose BGM from library"))
    XCTAssertTrue(source.contains("BGMCategory.allCases"))
    XCTAssertTrue(source.contains("viewModel.toggleBGM(item)"))
}
```

- [x] **Step 2: Verify the source test fails**

Run:

```bash
swift test --filter LiveModeLayoutTests/testLiveBGMCardOffersLibraryPickerWithoutLeavingLiveMode
```

Expected: failure because Live BGM only has transport plus an Audio page button.

- [x] **Step 3: Implement the menu**

Replace the single library icon with a `Menu` that groups non-empty categories and lets selecting a track call `viewModel.toggleBGM(item)`. Keep an `Open BGM Library` action inside the menu for full management.

- [x] **Step 4: Verify targeted tests pass**

Run:

```bash
swift test --filter LiveBGMQuickPickerModelTests
swift test --filter LiveModeLayoutTests/testLiveBGMCardOffersLibraryPickerWithoutLeavingLiveMode
```

Expected: pass.

### Task 3: Full Verification and PR

**Files:**
- No additional files unless verification exposes a bug.

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

Capture Live mode with the BGM card visible and confirm the compact picker button does not crowd the right rail.

- [ ] **Step 3: Create PR**

Commit and open:

```text
fix: let live mode choose BGM tracks
```

- [ ] **Step 4: CI and merge**

Watch checks and squash-merge automatically when green.
