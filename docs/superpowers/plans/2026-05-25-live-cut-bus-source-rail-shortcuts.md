# Live Cut Bus, Source Rail, And Setup Shortcut Plan

## Scope
- Rebalance Live mode Cut Bus so Take Next is the daily primary action and FTB is secondary unless active.
- Let the Live source rail shrink when there are no sources, giving monitor space back to the operator.
- Expose Setup sub-tabs through visible `⌘1/⌘2/⌘3` hints and a macOS Setup command menu.

## Files
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeLayoutMetrics.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/MainConsoleTab.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/App.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeMixerControlsTests.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ConsoleModeTests.swift`

## Verification
- Add failing tests first for source rail width, Cut Bus button semantics, and setup shortcuts.
- Run focused tests, then the full local chain:
  - `swift build`
  - `swift test`
  - `cd Sources/AnnualMeetingSwitcher && swift test`
  - `git diff --check`
  - `./script/check_release_hygiene.sh`
  - `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
  - `./script/build_and_run.sh --verify`
  - `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
  - `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
  - `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance
- Empty source rail uses `LiveModeLayoutMetrics.sourceRailWidthEmpty`, below the full rail width and within operator-safe bounds.
- Empty source rail no longer renders the large `EmptyStateView` block.
- Cut Bus renders `Take Next` as the wide primary action and `FTB` as the narrower secondary action; active FTB still uses danger styling.
- Setup menu labels and App commands expose `⌘1`, `⌘2`, and `⌘3` without affecting bare number shortcuts.
