# UI Overhaul Round 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Claude's round-three UI convergence findings without changing playback, projection, or audio-routing behavior beyond the explicitly requested UI semantics.

**Architecture:** Ship narrow PRs in the review order: J polish cleanup, L accessibility sweep, K monitor chrome auto-hide, and M mixer accent/i18n. Each PR starts with focused tests or source-hygiene tests, runs the full local verification chain, captures local UI screenshots for changed screens, then opens a PR and merges only after CI is green.

**Tech Stack:** Swift 6, SwiftUI/AppKit, SwiftPM tests, existing GitHub Actions smoke workflow, local macOS screenshot acceptance.

---

## Review Source

- Local brief: `LiveSwitcher-UI-overhaul-round3.md` from the user's review folder; do not commit local absolute paths.
- Base: `main` at `42451a4` or later.
- Explicitly out of this pass: full dark mode, full app i18n, Safety Cockpit/Preflight product merge, full `Font.system(size:)` sweep.

## PR J: Small Post-Refactor Polish

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/BGMPlaylistPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/HostSystemSummary.swift`
- Test: update `ToolbarLayoutMetricsTests`, `LeftPanelStaticTests`, `BGMPlaylistPanelStaticTests`, and overlay/source tests.

- [x] Add failing tests/source checks for help button height 46, no `line.3.horizontal` drag-handle symbols, empty overlay status text, sanitized UI footer version text, and Auto-next warning tint.
- [x] Align `helpButton` height to 46.
- [x] Remove decorative drag handles from Run Queue and BGM library rows while keeping row reordering.
- [x] Add `HostSystemSummary.shortVersionString` and use it in LiveOps runtime footer instead of `operatingSystemVersionString`.
- [x] Add EMPTY/READY/DRAFT/LIVE status logic to overlay composer sections using explicit draft-input detection.
- [x] Tint the Auto-next switch with `StudioTheme.Tone.warn`.
- [x] Run targeted tests, then the full local verification chain.
- [x] Capture local Run and Overlays screenshots and inspect toolbar alignment, no drag handles, EMPTY badge, and footer without build number.
- [x] Open PR, wait for CI, squash merge on green.

## PR L: Accessibility Decorative Icon Sweep

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- Modify: selected SwiftUI files under `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/`
- Test: create `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AccessibilityHiddenContractTests.swift`

- [x] Add source-hygiene tests for key view files proving SF Symbol images are either hidden as decoration or covered by explicit accessibility labels.
- [x] Hide pure decorative adjacent icons with `.accessibilityHidden(true)`.
- [x] Preserve transport/action button icons as semantic controls and ensure parent buttons have useful labels.
- [x] Add `LiveSwitcher main console` containment label to the main console container without changing visuals.
- [x] Run targeted accessibility/source tests, then the full local verification chain.
- [x] Capture local Run, Audio, and Overlays screenshots to confirm no visual changes.
- [x] Open PR, wait for CI, squash merge on green.

## PR K: Program Monitor Chrome Auto-Hide

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/MonitorChromeVisibility.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Test: create `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/MonitorChromeVisibilityTests.swift`

- [x] Add failing tests for `MonitorChromeVisibility.make(isPlaying:isHovering:isBroadcasting:)` and opacity mapping.
- [x] Add hover state to `ProgramMonitorView` preview deck.
- [x] Fade monitor inline status chrome out while media is playing and not hovered.
- [x] Keep a small bottom-right live indicator visible when broadcasting.
- [x] Run targeted monitor tests, then the full local verification chain.
- [x] Capture local Run screenshots for standby and playback-like states where feasible.
- [ ] Open PR, wait for CI, squash merge on green.

## PR M: Mixer Accent And Audio Strategy Localization

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AudioMixerView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/AudioStrategy.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/AudioMixerPageModel.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Resources/en.lproj/Localizable.strings`
- Test: update audio strategy and source-hygiene tests.

- [ ] Add failing tests/source checks for three mixer accent stripe colors and AudioStrategy localized keys.
- [ ] Add a semantic left accent stripe to `MixerFaderCard` for Master, Media, and BGM.
- [ ] Move `AudioStrategy.displayTitle` to stable localized keys while preserving ASCII raw values.
- [ ] Add `en` and `zh-Hans` Localizable strings for the four audio strategy labels.
- [ ] Ensure SwiftPM resources include the localization files and bundle localizations if required by the package layout.
- [ ] Run targeted audio/i18n tests, then the full local verification chain.
- [ ] Capture local Audio screenshots to inspect accent stripes and strategy labels.
- [ ] Open PR, wait for CI, squash merge on green.

## Verification For Every Code PR

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
- Local screenshots for changed screens.
- GitHub CI smoke tests green before squash merge.
