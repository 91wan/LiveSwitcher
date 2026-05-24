# Compact Setup Navigation Stage 43 Implementation Plan

**Goal:** Finish the remaining Round 5 setup-mode chrome reduction by merging the Setup mode selector and setup tab selector into one compact control row.

**Scope:** Top navigation only. No Live mode layout, playback, projection, audio routing, overlay, or persistence behavior changes.

## Task 1: Model and Tests

- [x] Add tab display metadata for the compact setup menu.
- [x] Update console-mode source tests so `ContentView` no longer keeps a separate `setupTabCluster`.
- [x] Verify the tests fail before the view is changed.

## Task 2: Implementation

- [x] Replace the stacked setup tab pill with a single setup-mode menu button.
- [x] Keep Live mode as a direct mode button and preserve setup tab switching through the menu.
- [x] Keep accessibility labels explicit for Setup and Live mode controls.

## Task 3: Verification and PR

- [x] Run full local verification:
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
- [x] Screenshot acceptance for compact Setup chrome.
- [ ] Open PR `fix: compact setup navigation chrome`.
- [ ] Watch CI and squash-merge automatically when green.
