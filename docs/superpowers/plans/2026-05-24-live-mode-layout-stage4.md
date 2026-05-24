# Live Mode Layout Stage 4 Plan

## Goal

Move `consoleMode == .live` from a compressed Run Desk into a dedicated single-screen live operating layout:

- left source rail with thumbnails and no setup/import controls
- large center Program Monitor with setup utilities hidden
- always-visible horizontal audio strip below the monitor
- right quick rail for output, overlays, wallpaper status, and BGM transport
- bottom runtime status line

This PR must not change playback, projection output, or audio-routing semantics.

## Scope

### In scope

1. Add a dedicated `LiveModeView` and narrow layout models/metrics.
2. Route live mode in `ContentView` to `LiveModeView` while keeping setup tabs retained.
3. Make `ProgramMonitorView(isLiveMode: true)` prioritize the monitor and hide setup utilities.
4. Reuse existing queue, projection, BGM, overlay, and audio state sources.
5. Add source-level and pure-model tests for layout contracts.
6. Run build/test/release hygiene plus local app screenshot verification.

### Out of scope

- VU meters, per-channel mute, cut bus, or full Stage 5 mixer behavior.
- Setup tab expansion to Wallpapers/Preflight.
- Any core playback/projection/audio-routing changes.
- VERSION changes.

## Files

Expected edits:

- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeLayoutMetrics.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`

## Implementation Steps

1. Add failing tests that lock the Stage 4 live-mode layout contract.
2. Add `LiveModeLayoutMetrics` with minimum rail, monitor, audio, quick-rail, and footer dimensions.
3. Add `LiveModeView` composed from `LiveSourceRail`, `LiveProgramStack`, `LiveAudioStrip`, `LiveQuickRail`, and `LiveRuntimeStatusBar`.
4. Update `ContentView.retainedTab(.preview)` so live mode displays `LiveModeView` instead of `runDesk(isLiveMode:)`.
5. Update `ProgramMonitorView` so live mode hides the header/utilities and removes the 342pt monitor cap.
6. Run tests, fix issues, then launch and screenshot the live layout.

## Verification Plan

Commands:

- `swift build`
- `swift test --filter LiveModeLayoutTests`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

Manual/screenshot verification:

- launch app
- switch to Live mode if needed
- capture a screenshot proving source rail, large monitor, horizontal audio strip, quick rail, and footer are visible

## Acceptance Criteria

- Live mode no longer renders the three-column setup Run Desk.
- Live mode has no Add Source, drag import zone, Auto-next, or wallpaper import controls.
- Program Monitor is the dominant live-mode element and is not capped at 342pt.
- Audio controls for Master, Media, and BGM are visible in live mode without switching tabs.
- Setup mode still retains Run, Audio, and Overlays tab state.
- Existing tests pass and app bundle verification succeeds.
