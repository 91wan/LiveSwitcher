# Stage 15: Chrome, Queue, and Help Typography Token Convergence

## Goal

Remove raw SwiftUI font literals from the main chrome title, Run Queue rail, and Help popover surfaces.

## Scope

- `ContentView.swift`
- `Views/LeftPanel.swift`
- `Views/HelpPopoverView.swift`
- Add focused source-hygiene tests.

## Non-goals

- No queue behavior changes.
- No file picker, drag/drop, or shortcut behavior changes.
- No Help copy changes.
- No layout redesign.

## Implementation

1. Add a source test that rejects `.font(.system(size:` in the scoped files.
2. Replace raw font literals with the closest existing `StudioTheme.TypeScale` token.
3. Keep output-composition fonts and BGM transport icon-size fonts out of this pass.

## Verification

- `swift test --filter ChromeQueueHelpTypographyConvergenceTests --filter HelpCopyModelTests --filter RunDeskControlConvergenceTests`
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

- The scoped files have zero raw `.font(.system(size:` calls.
- The scoped files reference `StudioTheme.TypeScale`.
- Existing Help and Run Desk tests still pass.
- No VERSION bump and no new dependencies.
