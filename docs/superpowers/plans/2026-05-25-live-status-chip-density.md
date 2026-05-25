# Live Status Chip Density Plan

## Scope
- Limit Live mode runtime status chips so the footer stops echoing every preflight warning during common fail states.
- Hide Cut Bus default READY chrome; only surface FTB when fade-to-black is active.
- Replace the remaining Chinese BGM Library subtitle in the Audio page with English copy.

## Files
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeRuntimeModels.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AudioMixerView.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveRuntimeStatusModelTests.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveModeLayoutTests.swift`
- `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/StatusBadgeVisibilityPolicyTests.swift`

## Verification
- Add failing model/source-contract tests first.
- Run focused tests for runtime status, badge visibility, and layout copy.
- Run the full local release chain before opening the PR:
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
- A synthetic preflight state with six fails and three warns produces two fail chips, one warn chip, a `+ 6 more` chip, and the summary chip.
- Cut Bus does not pass `READY` as a default status.
- Live quick card headers gate badges on both non-empty status text and the shared visibility policy.
- BGM Library subtitle reads `Categorize, list, add, remove, and reorder BGM tracks here.`
