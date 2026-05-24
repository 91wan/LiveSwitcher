# Live Audio Meter Estimate Stage 42 Implementation Plan

**Goal:** Make Live mode audio meters honest when a channel is estimated, and let Master use the available realtime BGM meter instead of only the master fader.

**Scope:** Meter display/model only. No audio routing, playback, projection, or volume behavior changes.

## Task 1: Meter Truth Model

- [x] Write failing tests for Master meter realtime source/fallback behavior and estimated meter copy.
- [x] Verify the tests fail because the helper and visible estimated affordance are missing.
- [x] Add ViewModel helpers for Live Master meter realtime/fallback volume.
- [x] Add estimated copy/icon affordance to Live audio faders.
- [x] Verify targeted tests pass.

## Task 2: Full Verification and PR

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
- [x] Screenshot acceptance.
- [ ] Open PR `fix: clarify estimated live audio meters`.
- [ ] Watch CI and squash-merge automatically when green.
