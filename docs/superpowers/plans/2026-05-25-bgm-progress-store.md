# BGM Progress Store Performance Plan

**Goal:** Reduce BGM playback UI invalidation by throttling progress updates and moving progress state out of `SwitcherViewModel`.

**Scope:** Round 8 PP steps 1 and 2 only. Do not change audio routing, playback semantics, ticker output frame rate, or the main app information architecture.

## Implementation

- [x] Add `BGMProgressStore` with `progress`, `currentTime`, `duration`, `reset()`, and `update(currentTime:duration:)`.
- [x] Set the BGM progress timer to `BGMProgressStore.updateInterval` at 0.1 seconds.
- [x] Replace `@Published` BGM progress triplet on `SwitcherViewModel` with compatibility accessors backed by `bgmProgressStore`.
- [x] Make the BGM library progress bar observe `BGMProgressStore` directly.
- [x] Keep ticker overlay timer unchanged at 60fps.
- [x] Add tests for store behavior, timer rate, source hygiene, and direct store observation.

## Verification

- [x] `swift test --filter BGMProgressStoreTests`
- [x] `swift build`
- [x] `swift test`
- [x] `cd Sources/AnnualMeetingSwitcher && swift test`
- [x] `git diff --check`
- [x] `./script/check_release_hygiene.sh`
- [x] `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- [x] `./script/build_and_run.sh --verify`
- [x] `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- [x] `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- [x] `codesign --verify --deep --strict dist/LiveSwitcher.app`
- [x] Computer Use screenshot acceptance on the Audio/BGM library progress bar.

## Deferred

- [x] Document the `@Observable` migration as a follow-up RFC instead of including it in this PR.
