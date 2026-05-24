# BGM Waveform Thumbnails Stage 6 Plan

## Goal

Finish the Round 4 follow-up item that was intentionally left out of the first thumbnail PR: show BGM waveform thumbnails in the Audio page library so similarly named tracks are easier to distinguish before playback.

## Scope

### In scope

1. Reuse `ThumbnailService` for BGM audio files.
2. Replace the icon-only BGM library row leading glyph with a small waveform thumbnail.
3. Generate waveform bars from readable audio samples when possible, with the existing dark audio placeholder as fallback.
4. Add pure/service tests for waveform sample extraction and static UI wiring.

### Out of scope

- Changing BGM playback behavior, routing, categories, duplicate policy, or transport controls.
- Adding BGM thumbnails to Live mode mini controls.
- Adding new dependencies.
- VERSION changes.

## Verification Plan

- `swift build`
- `swift test --filter ThumbnailServiceTests`
- `swift test --filter BGMPlaylistPanelStaticTests`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- screenshot the Audio page with BGM library rows visible
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance Criteria

- BGM library rows show a 16:9-ish waveform thumbnail instead of relying only on a small SF Symbol.
- Audio thumbnails are cacheable by URL, source kind, size, and mtime as before.
- Invalid or unsupported audio files still get a safe fallback thumbnail.
- Existing BGM controls and list actions remain unchanged.
