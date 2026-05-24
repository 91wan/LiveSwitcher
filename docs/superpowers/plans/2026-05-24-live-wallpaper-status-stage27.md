# Live Wallpaper Status Implementation Plan

**Goal:** Replace Live mode's bare `0` wallpaper warning badge with an explicit operator-facing status.

**Scope:** One pure quick-status model plus the Live mode wallpaper quick card. No wallpaper import, selection, or cycling behavior changes.

---

### Task 1: Model Live Wallpaper Quick Status

**Files:**
- Add: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveWallpaperQuickStatusModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveWallpaperQuickStatusModelTests.swift`

- [x] **Step 1: Write failing model tests**

Assert empty wallpaper library uses `NO WALLPAPER` warn status instead of a bare `0`, while populated libraries stay ready and cycle only when at least two wallpapers exist.

- [x] **Step 2: Verify RED**

Run: `swift test --filter LiveWallpaperQuickStatusModelTests`

- [x] **Step 3: Implement model and wire Live mode card**

Use the model in `LiveQuickRail.wallpaperCard` for status text, active title, and cycle availability.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter LiveWallpaperQuickStatusModelTests`

- [x] **Step 5: Full verification and screenshot**

Run the standard verification chain and capture the app to confirm the Live/Setup console remains stable.
