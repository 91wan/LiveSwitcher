# Stage 16: StudioTheme Generic Component Typography Convergence

## Goal

Remove raw SwiftUI font view modifiers from reusable StudioTheme components so feature views inherit typography through the shared type scale.

## Scope

- `Views/StudioTheme.swift`
- `StudioThemeTokenContractTests`

## Non-goals

- No output overlay typography changes.
- No BGM panel typography sweep.
- No new theme tokens.
- No layout redesign or behavior change.

## Implementation

1. Add a focused source hygiene test that rejects `.font(.system(size:` inside reusable StudioTheme components.
2. Replace raw font view modifiers in shared components with existing `StudioTheme.TypeScale` tokens.
3. Leave `Font.system(size:)` declarations inside `TypeScale` explicit.

## Verification

- `swift test --filter StudioThemeTokenContractTests`
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

- `StudioTheme.swift` has zero `.font(.system(size:` view modifiers.
- `TypeScale` token declarations remain explicit.
- Studio theme token tests pass.
- No VERSION bump and no new dependencies.
