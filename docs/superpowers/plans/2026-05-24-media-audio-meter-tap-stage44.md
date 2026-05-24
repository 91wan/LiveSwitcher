# Media Audio Meter Tap Stage 44 Implementation Plan

**Goal:** Finish the remaining Round 5 metering gap by replacing Live mode media fader estimates with realtime AVPlayer audio level readings when the current media item exposes an audio track.

**Scope:** Media metering only. No playback controls, routing policy, projection, BGM library, overlay, or visual architecture changes.

## Task 1: Model and Tests

- [x] Add a pure audio power helper for dBFS conversion.
- [x] Test silence, half-scale, full-scale, and empty-sample behavior.
- [x] Update Live mode source tests so the media fader uses `avCoordinator.realtimeLevelDB` instead of a hard-coded estimated meter.

## Task 2: Implementation

- [x] Add an AVPlayer audio processing tap that reads source audio and publishes media dB levels.
- [x] Reset media realtime meter when media stops or the tap is unavailable.
- [x] Include media realtime dB in the master meter choice while keeping existing BGM metering.

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
- [x] Screenshot acceptance for Live mode meter labels: `/tmp/liveswitcher-stage44/live-meter.png`.
- [ ] Open PR `fix: meter live media audio levels`.
- [ ] Watch CI and squash-merge automatically when green.
