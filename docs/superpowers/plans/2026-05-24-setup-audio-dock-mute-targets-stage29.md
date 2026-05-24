# Setup Audio Dock Mute Hit Target Stage 29 Plan

## Goal

Bring Setup mode audio dock mute controls up to the same minimum operator hit-target standard used by Live mode and Live Ops.

## Scope

### In scope

1. Add a small layout metrics model for SetupAudioDock hit targets.
2. Replace the hard-coded 24x20 mute frame with a shared minimum 32pt square target.
3. Add static/model tests to prevent the small target from returning.

### Out of scope

- Audio routing behavior changes.
- Setup dock layout redesign.
- Live mode or LiveOps changes.
- VERSION changes.

## Verification Plan

- `swift test --filter SetupAudioDockModelTests/testSetupAudioDockMuteButtonsUseMinimumHitTarget`
- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- screenshot Setup mode with the audio dock visible
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance Criteria

- Setup Audio Dock mute buttons are at least 32x32.
- Setup Audio Dock no longer contains the 24x20 hard-coded mute frame.
- Existing mute bindings and audio routing behavior are unchanged.

## Tasks

- [x] Step 1: Write failing hit-target test.
- [x] Step 2: Verify RED with targeted test.
- [x] Step 3: Add metrics and update SetupAudioDock frame.
- [x] Step 4: Verify GREEN with targeted test.
- [x] Step 5: Run full verification and screenshot.
