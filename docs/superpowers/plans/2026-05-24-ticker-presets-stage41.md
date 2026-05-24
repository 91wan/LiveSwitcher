# Ticker Presets Stage 41 Implementation Plan

**Goal:** Let operators prepare reusable ticker text in Setup and start a selected ticker directly from Live mode.

**Scope:** Ticker presets only. Lower Third, Countdown, BGM, and Wallpaper quick-pickers are already shipped. No playback, projection, or audio-routing changes.

## Task 1: Ticker Preset Model and ViewModel API

- [x] Write failing tests for ticker preset sanitization, speed-index normalization, persistence, draft loading, deletion, and live start.
- [x] Verify `swift test --filter TickerPresetTests` fails because the model/API does not exist.
- [x] Add `TickerPreset`, `tickerPresets` persistence, and ViewModel save/load/delete/start APIs.
- [x] Verify `swift test --filter TickerPresetTests` passes.

## Task 2: Setup and Live UI Wiring

- [x] Write failing source contract tests for Setup ticker preset shelf and Live ticker preset menu.
- [x] Verify the source contract tests fail with the missing model/API red phase.
- [x] Add the Setup ticker preset shelf and Live ticker preset menu.
- [x] Verify ticker preset tests plus the source contract tests pass.

## Task 3: Verification and PR

- [x] Run full local verification:
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
- [x] Screenshot acceptance using Computer Use/background-safe capture where possible.
- [ ] Open PR `fix: add ticker presets for live mode`.
- [ ] Watch CI and squash-merge automatically when green.
