# Stage 17: BGM Library Typography Token Convergence

## Goal

Remove raw SwiftUI font literals from the BGM Library panel and row controls while preserving BGM playback, import, and reorder behavior.

## Scope

- `Views/BGMPlaylistPanel.swift`
- `BGMPlaylistPanelStaticTests`

## Non-goals

- No BGM playback or routing behavior changes.
- No BGM import policy changes.
- No BGM layout redesign.
- No output overlay typography changes.

## Implementation

1. Add a source hygiene test rejecting `.font(.system(size:` in `BGMPlaylistPanel.swift`.
2. Replace transport, progress, category, add-button, status, and row font literals with existing `StudioTheme.TypeScale` tokens.
3. Keep existing BGMControlsState wiring and row thumbnail behavior unchanged.

## Verification

- `swift test --filter BGMPlaylistPanelStaticTests --filter BGMControlsStateTests`
- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- Screenshot running app for visual sanity.
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance

- `BGMPlaylistPanel.swift` has zero raw `.font(.system(size:` calls.
- BGM panel static tests pass.
- BGM controls state tests still pass.
- No VERSION bump and no new dependencies.
