# Live Wallpaper Picker Stage 38 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let operators choose a specific standby wallpaper directly from Live mode instead of cycling blindly through the wallpaper list.

**Architecture:** Reuse the existing `backgroundWallpapers` array and `setActiveWallpaper(url:)` API. Add a pure `LiveWallpaperQuickPickerModel` that maps wallpaper URLs into compact picker items with active state, then wire the Live wallpaper card to a horizontal picker strip.

**Tech Stack:** Swift, SwiftUI, XCTest, SwiftPM.

---

### Task 1: Live Wallpaper Picker Model

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveWallpaperQuickPickerModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveWallpaperQuickPickerModelTests.swift`

- [x] **Step 1: Write failing model tests**

Cover empty library, active wallpaper mapping, title fallback, and item order.

- [x] **Step 2: Verify tests fail**

Run:

```bash
swift test --filter LiveWallpaperQuickPickerModelTests
```

Expected: compile failure because `LiveWallpaperQuickPickerModel` does not exist.

- [x] **Step 3: Implement model**

Add a small `Equatable` model with `items`, `displayTitle`, `statusText`, `statusKind`, and `isEmpty`.

- [x] **Step 4: Verify model tests pass**

Run:

```bash
swift test --filter LiveWallpaperQuickPickerModelTests
```

Expected: tests pass.

### Task 2: Live Wallpaper Picker Strip

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

- [x] **Step 1: Write failing source contract test**

Assert the Live wallpaper rail uses the picker model, selects a specific URL, and no longer exposes `Next wallpaper`.

- [x] **Step 2: Verify source test fails**

Run:

```bash
swift test --filter LiveModeLayoutTests/testLiveWallpaperCardSelectsSpecificWallpaperInsteadOfCycling
```

Expected: failure because Live wallpaper only exposes `Next wallpaper`.

- [x] **Step 3: Implement picker strip**

Replace the blind cycle button with a compact horizontal strip of wallpaper buttons. Each button calls `viewModel.setActiveWallpaper(url:)`; the active item gets the existing primary selection stroke.

- [x] **Step 4: Verify targeted tests pass**

Run:

```bash
swift test --filter LiveWallpaperQuickPickerModelTests
swift test --filter LiveModeLayoutTests/testLiveWallpaperCardSelectsSpecificWallpaperInsteadOfCycling
```

Expected: pass.

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

Capture Live mode and confirm the right rail remains compact with the wallpaper picker visible.

- [ ] **Step 3: Create PR**

Commit and open:

```text
fix: let live mode choose standby wallpaper
```

- [ ] **Step 4: CI and merge**

Watch checks and squash-merge automatically when green.
