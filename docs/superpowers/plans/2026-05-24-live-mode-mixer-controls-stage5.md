# Live Mode Mixer Controls Stage 5 Plan

## Goal

Harden the new Live mode runtime controls without changing the setup pages:

- add live audio meters to the always-visible bottom mixer
- add explicit master/media/BGM mute controls that feed the existing audio routing engine
- turn the right-rail blackout card into a small Cut Bus with Fade to Black and Take Next
- make the bottom runtime footer render preflight exception status instead of a generic-only line

## Scope

### In scope

1. Extend `AudioRoutingInput` and `SwitcherViewModel` with non-persistent live mute state.
2. Add pure models:
   - `LiveAudioMeterModel`
   - `LiveCutBusModel`
   - `LiveRuntimeStatusModel`
3. Update `LiveAudioStrip`, `LiveQuickRail`, and `LiveRuntimeStatusBar`.
4. Add model and routing tests.
5. Run the full validation chain and screenshot the Live mode layout.

### Out of scope

- Actual low-level audio peak metering from AVAudioEngine.
- Solo/PFL behavior.
- New setup pages for Wallpapers or Preflight.
- Release version changes.

## Verification Plan

- `swift build`
- `swift test --filter LiveModeMixerControlsTests`
- `swift test --filter AudioRoutingEngineTests`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance Criteria

- Live mode mixer shows Master, Media, and BGM meters.
- Mute buttons are real controls: effective output goes to zero through `AudioRoutingEngine`.
- Cut Bus can fade to black through existing Panic behavior and can take the next queue item when one exists.
- Runtime footer prioritizes fail/warn preflight exceptions over generic standby text.
- Stage 4 layout remains visible at 1360x700.
