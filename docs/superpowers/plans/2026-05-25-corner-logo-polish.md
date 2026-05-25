# Corner Logo And Enterprise Polish Plan

**Goal:** Finish Round 7 JJ by adding persistent enterprise corner logo display and tightening the remaining Live UI wording/density edges for company-event use.

**Scope:**
- Add an optional persistent corner logo URL and position.
- Render the logo in output above program/overlay content but below blackout/panic.
- Add setup controls near Standby Wallpaper.
- Tighten Live overlay rail preset labels.
- Rename Panic copy to neutral Blackout copy.
- Remove the Setup menu ellipsis.
- Make runtime overflow chips say warnings/issues instead of vague "more".

**Non-goals:**
- No recording, streaming, multi-monitor architecture changes, playback changes, or routing changes.
- No VERSION bump.
- No new dependencies.

## Steps

- [x] Add pure tests for corner logo defaults, persistence, output layering hooks, and setup UI hooks.
- [x] Add tests for panic copy, setup menu ellipsis removal, overlay rail tail truncation, and runtime overflow copy.
- [x] Implement corner logo model, ViewModel persistence/mutations, output layer, and setup card.
- [x] Implement copy/polish fixes.
- [x] Run focused tests and fix failures.
- [x] Run full local verification chain and Computer Use screenshot acceptance.
- [ ] Commit, open PR, watch CI, and squash merge when green.

## Verification

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
- Computer Use screenshot acceptance for Setup Run and Live mode after polish.

## Acceptance

- Existing users see no logo by default.
- Imported logo persists and can be removed.
- Logo position persists and maps to all four corners.
- Panic top action says Blackout, not 老板键.
- Setup mode control has only one chevron disclosure indicator.
- Live overlay rows reserve width for preset names and use tail truncation.
- Runtime status overflow says warnings/issues.
