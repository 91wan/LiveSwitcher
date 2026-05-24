# Countdown Presets Stage 40 Implementation Plan

**Goal:** Let operators prepare reusable countdown timers in Setup and start a selected countdown directly from Live mode.

**Scope:** Countdown presets only. Lower Third presets already shipped. Ticker presets stay in the next PR.

## Task 1: Countdown Preset Model and ViewModel API

- [x] Write failing tests for countdown preset sanitization, validation, persistence, draft loading, deletion, and live start.
- [x] Verify `swift test --filter CountdownPresetTests` fails because the model/API does not exist.
- [x] Add `CountdownPreset`, `countdownPresets` persistence, and ViewModel save/load/delete/start APIs.
- [x] Verify `swift test --filter CountdownPresetTests` passes.

## Task 2: Setup and Live UI Wiring

- [x] Write failing source contract tests for Setup countdown preset shelf and Live countdown preset menu.
- [x] Verify the source contract tests fail.
- [x] Add the Setup countdown preset shelf and Live countdown preset menu.
- [x] Verify countdown preset tests plus the source contract tests pass.

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
- [ ] Open PR `fix: add countdown presets for live mode`.
- [ ] Watch CI and squash-merge automatically when green.
