# Stage 18: Output Typography Boundary Hygiene

## Goal

Make the remaining raw SwiftUI font literals intentional by limiting them to projected overlay composition views and removing stale debug typography from Panic output.

## Scope

- `Views/PanicLayer.swift`
- `OutputTypographyBoundaryTests`

## Non-goals

- No Lower Third or Countdown composition typography changes.
- No projected output behavior changes.
- No Panic behavior changes beyond removing dead commented code.

## Implementation

1. Add source hygiene tests that allow raw `.font(.system(size:` only in projected overlay composition views.
2. Remove the old commented debug text from `PanicLayer`.
3. Keep Panic output as pure black.

## Verification

- `swift test --filter OutputTypographyBoundaryTests`
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

- PanicLayer contains no commented debug typography.
- Raw SwiftUI font literals are limited to LowerThird and Countdown projected overlay composition files.
- No VERSION bump and no new dependencies.
