# UI Redesign Round 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the strategic broadcast-console redesign by shipping dark-theme readiness, source thumbnails, and a Setup/Live mode switcher as separate, testable PRs.

**Architecture:** Keep playback, projection, and audio-routing behavior unchanged. Ship the migration in three narrow PRs: dynamic theme tokens first, source thumbnails second, and ConsoleMode IA scaffolding third. Each PR adds pure model/source tests, local app verification, screenshot acceptance, GitHub CI, and squash merge on green.

**Tech Stack:** Swift 6, SwiftUI/AppKit, AVFoundation/WebKit/QuickLookThumbnailing where needed, SwiftPM tests, existing package and app-bundle scripts.

---

## Review Source

- Local brief: `LiveSwitcher-UI-redesign-round4.md` from the review handoff.
- Baseline: `main` at `a9310bc` or later.
- Owner alignment: accepted by the user's instruction to continue through the Claude review work without stopping.
- Explicitly out of this first migration batch: the full Stage 4 live-layout rewrite, VU meters, Cut Bus expansion, BGM waveform thumbnails, Cockpit/Popover product merge, and a full app i18n sweep.

## PR N: Dynamic Theme Tokens

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ThemeOverride.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/App.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ThemeTokenTests.swift`

- [x] Create this plan file and branch from clean `main`.
- [x] Add failing source tests proving `ContentView` no longer forces `.preferredColorScheme(.light)` and `StudioTheme` exposes dynamic light/dark token helpers for canvas, text, surface, tones, and actions.
- [x] Replace static light-only StudioTheme colors with dynamic `NSColor` providers, preserving monitor dark colors.
- [x] Add `ThemeOverride` with `system`, `light`, and `dark`, persist it in `SwitcherViewModel`, and expose `preferredColorScheme`.
- [x] Wire a `View -> Theme -> System / Light / Dark` command menu that changes the active override.
- [x] Run targeted theme tests, then the full local verification chain.
- [x] Capture Run, Audio, and Overlays screenshots in dark and light modes.
- [ ] Open PR, wait for CI, and squash merge on green.

## PR O: Program Source Thumbnails

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/ThumbnailService.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ThumbnailView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift` if `SignalSourceRow` still lives there.
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ThumbnailServiceTests.swift`

- [ ] Add failing tests for deterministic thumbnail cache keys, cache directory location, source-kind fallback symbols, and cache invalidation on mtime changes.
- [ ] Implement `ThumbnailService` as an actor with cached async generation for media, HTML, and presentation sources.
- [ ] Render 48x27 16:9 thumbnails in program rows with loading and fallback states.
- [ ] Keep BGM waveform thumbnails out of this PR, per the review brief.
- [ ] Run targeted thumbnail tests, then the full local verification chain.
- [ ] Capture Run Queue screenshots with media, HTML, and presentation/fallback rows.
- [ ] Open PR, wait for CI, and squash merge on green.

## PR P: Setup / Live Mode Switcher

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ConsoleMode.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/App.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ConsoleModeTests.swift`

- [ ] Add failing tests for default `.setup`, persistence, localization keys, and live-mode UI source contracts.
- [ ] Add `ConsoleMode` to `SwitcherViewModel`, persisted to `UserDefaults`.
- [ ] Replace the top three-tab cluster with a Setup/Live mode segmented control, and render setup tabs only in Setup mode.
- [ ] In Live mode, retain the Run Desk but hide setup-only controls: Add Source/dropzone, Auto-next, Keynote refresh, and wallpaper management.
- [ ] Make Panic visually stronger in Live mode without moving Speaker/PPT back into the toolbar.
- [ ] Add menu commands for `Command-Shift-S` Setup and `Command-Shift-L` Live.
- [ ] Run targeted console-mode tests, then the full local verification chain.
- [ ] Capture Setup and Live mode screenshots.
- [ ] Open PR, wait for CI, and squash merge on green.

## Verification For Every PR

- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`
- Local screenshots for changed screens.
- GitHub CI smoke tests green before squash merge.
