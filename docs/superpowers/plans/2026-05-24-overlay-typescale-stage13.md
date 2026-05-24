# Stage 13: Overlay Typography Token Convergence

## Goal

Remove remaining raw SwiftUI font literals from the overlay control surface so the post-redesign overlay composer and live preview use the shared `StudioTheme.TypeScale` contract.

## Scope

- `Views/OverlayControlPanel.swift`
- `Views/OverlayLivePreviewCanvas.swift`
- Add focused source-hygiene tests.

## Non-goals

- No overlay behavior changes.
- No layout redesign.
- No output-window overlay rendering changes.
- No playback, projection, or audio-routing changes.

## Implementation

1. Add tests that reject `.font(.system(size:` in the two overlay UI files and require `StudioTheme.TypeScale`.
2. Replace raw font literals with the closest existing TypeScale token plus local weight/design modifiers.
3. Keep monitor/program-output overlay views (`CountdownOverlay`, `LowerThirdOverlay`) out of this pass because those fonts are part of output composition sizing.

## Verification

- `swift test --filter OverlayTypographyConvergenceTests`
- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- Screenshot the running app for visual sanity.
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance

- Overlay control and preview files have zero raw `.font(.system(size:` calls.
- Both files use `StudioTheme.TypeScale`.
- Existing overlay model and input tests still pass.
- The app launches and the overlay screen remains readable in screenshot verification.
