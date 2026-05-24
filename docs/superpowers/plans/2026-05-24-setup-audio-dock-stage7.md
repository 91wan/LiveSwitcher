# Setup Audio Dock Stage 7 Plan

## Goal

Finish the Round 4 follow-up item "Audio Mixer forever at the bottom" in a scoped way: keep a compact audio dock visible in Setup mode when the operator is on Run Queue or Overlays, without changing the full Audio page.

## Scope

### In scope

1. Add a pure `SetupAudioDockModel` for visibility and percent formatting.
2. Add a compact `SetupAudioDock` view with Master/Media/BGM sliders, effective output text, mute toggles, and an Open Mixer action.
3. Show the dock only in Setup mode on non-Audio tabs to avoid duplicating the full mixer page.
4. Add model/static tests.

### Out of scope

- Changing audio routing strategy semantics.
- Redesigning the Audio page.
- Adding solo/PFL or new metering.
- VERSION changes.

## Verification Plan

- `swift build`
- `swift test --filter SetupAudioDockModelTests`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- screenshot Run or Overlays showing the dock
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance Criteria

- Setup Run and Overlays pages expose baseline audio controls without switching to Audio.
- Setup Audio page does not show a duplicate compact dock.
- Live mode remains controlled by the dedicated Live bottom mixer.
- Mute buttons feed the existing view model mute states.
