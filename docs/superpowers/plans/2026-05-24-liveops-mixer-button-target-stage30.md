# Live Ops Mixer Button Hit Target Stage 30 Plan

## Goal

Keep the Live Ops "Mixer" navigation control large enough for operator use by replacing the remaining 28pt button target with a shared metric.

## Scope

### In scope

1. Add a secondary Live Ops button height metric with a 32pt minimum.
2. Wire the Live Ops Audio card Mixer button to that metric.
3. Add static/model tests to prevent the 28pt target from returning.

### Out of scope

- Audio routing behavior.
- Live Ops information architecture changes.
- Audio page changes.
- VERSION changes.

## Verification Plan

- `swift test --filter LiveOpsLayoutMetricsTests/testLiveOpsMixerButtonUsesMinimumHitTarget`
- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- screenshot Run Desk with Live Ops visible
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`
- `codesign --verify --deep --strict dist/LiveSwitcher.app`

## Acceptance Criteria

- Live Ops Mixer button height is at least 32pt.
- `LiveOpsPanel.swift` no longer contains the 28pt mixer button frame.
- Existing Open Mixer behavior is unchanged.

## Tasks

- [x] Step 1: Write failing Mixer button hit-target test.
- [x] Step 2: Verify RED with targeted test.
- [x] Step 3: Add metric and update LiveOpsPanel.
- [x] Step 4: Verify GREEN with targeted test.
- [x] Step 5: Run full verification and screenshot.
