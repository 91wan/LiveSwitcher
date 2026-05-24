# Stage 14: Audio Mixer Typography Token Convergence

## Goal

Remove remaining raw SwiftUI font literals from `AudioMixerView.swift` so the redesigned Audio page uses the shared typography scale.

## Scope

- `Views/AudioMixerView.swift`
- Add focused source-hygiene tests.

## Non-goals

- No mixer layout changes.
- No audio-routing or fader behavior changes.
- No BGM library transport typography changes in this pass.

## Implementation

1. Add a source test that rejects `.font(.system(size:` in `AudioMixerView.swift`.
2. Replace raw font literals with existing `StudioTheme.TypeScale` tokens.
3. Re-run audio page and routing tests along with the full verification chain.

## Verification

- `swift test --filter AudioMixerTypographyConvergenceTests --filter AudioMixerLocalizationTests --filter AudioTransitionControlModelTests`
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

- `AudioMixerView.swift` has zero raw `.font(.system(size:` calls.
- `AudioMixerView.swift` uses `StudioTheme.TypeScale`.
- Existing audio page and transition model tests still pass.
- No VERSION bump and no new dependencies.
