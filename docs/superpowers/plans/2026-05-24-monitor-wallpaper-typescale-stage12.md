# Monitor Wallpaper TypeScale Convergence Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Continue Round 3 N6 typography convergence around the Program monitor and standby wallpaper controls.

**Scope:** Replace raw `.font(.system(size: ...))` calls in `ProgramMonitorView.swift`, `WallpaperGalleryRow.swift`, and `ThumbnailView.swift` with existing `StudioTheme.TypeScale` tokens. Preserve monitor layout, wallpaper import behavior, thumbnail loading, and output/runtime logic.

---

### Task 1: Source Hygiene Test

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/MonitorWallpaperTypographyConvergenceTests.swift`

- [ ] Assert `Views/ProgramMonitorView.swift` has no `.font(.system(size:` calls and uses `StudioTheme.TypeScale`.
- [ ] Assert `Views/WallpaperGalleryRow.swift` has no `.font(.system(size:` calls and uses `StudioTheme.TypeScale`.
- [ ] Assert `Views/ThumbnailView.swift` has no `.font(.system(size:` calls and uses `StudioTheme.TypeScale`.
- [ ] Run `swift test --filter MonitorWallpaperTypographyConvergenceTests` and confirm it fails before implementation.

### Task 2: Replace Raw Font Literals

**Files:**
- Modify: `Views/ProgramMonitorView.swift`
- Modify: `Views/WallpaperGalleryRow.swift`
- Modify: `Views/ThumbnailView.swift`

- [ ] Use `StudioTheme.TypeScale.display` for large monitor idle/source titles.
- [ ] Use `StudioTheme.TypeScale.heading/body/caption/label` for monitor chrome and wallpaper controls.
- [ ] Use `StudioTheme.TypeScale.numeric` for transition duration.
- [ ] Do not alter monitor max height, wallpaper import, drag/drop, or thumbnail behavior.

### Task 3: Verification and PR

- [ ] Run targeted tests:
  - `swift test --filter MonitorWallpaperTypographyConvergenceTests --filter ProgramMonitorInfoBlockModelTests --filter ThumbnailServiceTests`
- [ ] Run required local gates:
  - `swift build`
  - `swift test`
  - `cd Sources/AnnualMeetingSwitcher && swift test`
  - `git diff --check`
  - `./script/check_release_hygiene.sh`
  - `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
  - `./script/build_and_run.sh --verify`
  - screenshot the LiveSwitcher window
  - `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
  - `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
  - `codesign --verify --deep --strict dist/LiveSwitcher.app`
- [ ] Commit, open PR, wait for CI, and merge when green.

Acceptance criteria:
- The monitor/wallpaper/thumbnail view files no longer contain raw `.font(.system(size:` calls.
- Existing monitor, wallpaper, and thumbnail tests continue to pass.
- No new dependency or VERSION change.
