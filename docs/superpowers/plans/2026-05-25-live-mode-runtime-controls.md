# Live Mode Runtime Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Fix Round 8 OO live-mode runtime correctness so Live mode can reliably navigate to setup pages, expose Speaker/PPT controls, and manage BGM without leaving live mode.

**Architecture:** Add small pure models/tests for navigation and live BGM playlist state, then wire `LiveModeView` to those models. Keep playback, routing, and projection logic unchanged.

**Tech Stack:** SwiftPM, SwiftUI, XCTest.

---

### Task 1: Live-To-Setup Navigation Helper

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ConsoleNavigationTests.swift`

- [x] **Step 1: Write failing tests**

Add tests that construct `SwitcherViewModel`, set `consoleMode = .live`, call `navigateToSetup(.audioMixer)`, and assert setup mode plus target tab. Add source hygiene assertions that live-to-setup UI code uses `navigateToSetup` rather than setting only `selectedMainTab`.

- [x] **Step 2: Run test to verify RED**

Run:

```bash
swift test --filter ConsoleNavigationTests
```

Expected: fail because `navigateToSetup` does not exist or source checks fail.

- [x] **Step 3: Implement helper and replace direct tab navigation**

Add:

```swift
func navigateToSetup(_ tab: MainConsoleTab) {
    consoleMode = .setup
    selectedMainTab = tab
}
```

Use it for live-mode mixer, overlay setup, wallpaper setup, setup menu, and preflight tab navigation.

- [x] **Step 4: Run test to verify GREEN**

Run:

```bash
swift test --filter ConsoleNavigationTests
```

Expected: pass.

### Task 2: Live Modes Card

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [x] **Step 1: Write failing tests**

Assert `LiveQuickRail` includes `modesCard` between `outputCard` and `cutBusCard`, and that the source contains toggles bound to `$viewModel.isSpeakerMode` and `$viewModel.isPageInterceptEnabled`.

- [x] **Step 2: Run RED**

```bash
swift test --filter LiveModeLayoutTests/testLiveModeQuickRailIncludesSpeakerAndPPTModes
```

Expected: fail because the modes card is missing.

- [x] **Step 3: Implement card**

Add `modesCard` with two compact toggles:

```swift
Toggle(isOn: $viewModel.isSpeakerMode) { ... }
Toggle(isOn: $viewModel.isPageInterceptEnabled) { ... }
```

Place it after `outputCard` and before `cutBusCard`.

- [x] **Step 4: Run GREEN**

```bash
swift test --filter LiveModeLayoutTests/testLiveModeQuickRailIncludesSpeakerAndPPTModes
```

Expected: pass.

### Task 3: Live BGM Mini Playlist

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveBGMPlaylistModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveBGMPlaylistModelTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [x] **Step 1: Write failing model tests**

Cover empty library, selected category rows, current-item category sync, current-row playing state, and category menu title `切换分类`.

- [x] **Step 2: Run RED**

```bash
swift test --filter LiveBGMPlaylistModelTests
```

Expected: fail because `LiveBGMPlaylistModel` does not exist.

- [x] **Step 3: Implement model and UI wiring**

Create `LiveBGMPlaylistModel.make(items:currentItem:selectedCategory:isPlaying:)`. In `LiveQuickRail`, store `@State private var liveBGMCategory`, render 3-5 visible rows, and replace the old “Open BGM Library” menu item with a category-only menu labelled `切换分类`.

- [x] **Step 4: Run GREEN**

```bash
swift test --filter LiveBGMPlaylistModelTests
swift test --filter LiveModeLayoutTests/testLiveBGMCardShowsMiniPlaylistWithoutSetupNavigation
```

Expected: pass.

### Task 4: Local Verification And PR

**Files:**
- No new production files unless tests reveal a blocker.

- [x] **Step 1: Run required verification**

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

Launch the app, switch to Live mode, and capture a background screenshot verifying:
- Quick rail shows Output, Modes, Cut Bus, Overlays, Wallpaper, BGM.
- Modes contains Speaker and PPT toggles.
- BGM card shows transport and mini playlist/category control.

- [x] **Step 3: Commit, open PR, wait for CI, merge**

Use a focused PR title:

```text
fix: restore live mode runtime controls
```

PR summary must list navigation helper, Speaker/PPT live modes, BGM mini playlist, and verification commands.

---

## Deferred Follow-Up

Round 8 PP and QQ remain separate follow-up PRs:
- PP: reduce BGM progress updates from 30fps to 10fps and extract `BGMProgressStore`.
- QQ: Chinese-first label cleanup while preserving BGM/PPT/HTML/PPTX/Keynote/dB/FTB terms.
