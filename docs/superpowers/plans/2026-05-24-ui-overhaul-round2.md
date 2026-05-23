# UI Overhaul Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Claude's round-two UI convergence findings without changing playback, projection, or audio-routing behavior.

**Architecture:** Ship four narrow PRs: routing banner semantics, Run monitor chrome cleanup, Live Ops controls, and Overlay polish. Each PR uses model or source-hygiene tests where possible, then runs the full local release verification before PR creation.

**Tech Stack:** Swift 6, SwiftUI/AppKit, SwiftPM tests, existing GitHub Actions smoke workflow.

---

## Review Source

- Local brief: `LiveSwitcher-UI-overhaul-round2.md` from the user's review folder; do not commit local absolute paths.
- Base: `main` at `4422887`
- Backlog intentionally out of this pass: real dark mode, i18n, VoiceOver sweep, Safety Cockpit/Preflight merge, mixer channel accent bars, Help button height, drag-handle cleanup.

## PR F: Routing Banner Semantics

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/AudioMixerPageModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioOverlayInformationHierarchyTests.swift`
- Test: add or update a source-level StudioTheme test for `InlineWarningBanner` icon mapping.

- [x] Add failing tests proving `InlineWarningBanner` maps `.ready` to `checkmark.seal.fill`, `.warn` to `exclamationmark.triangle.fill`, `.fail` to `xmark.octagon.fill`, `.live` to `dot.radiowaves.left.and.right`, and `.idle/.muted` to `info.circle.fill`.
- [x] Add failing test proving `AudioMixerPageModel.routingStatusKind` returns `.idle` when no emergency state is active.
- [x] Implement `InlineWarningBanner.iconName` with a `switch kind`.
- [x] Change `routingStatusKind` fallback from `.ready` to `.idle`.
- [x] Verify `routingImpactText` and `channelLimitText` still report `No emergency routing...` and `No forced mute`.
- [x] Run targeted tests, then full local verification.
- [ ] Open PR, wait for CI, squash merge on green.

## PR G: Run Monitor Chrome Convergence

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Test: update `RunDeskControlConvergenceTests`, `RunDeskInformationHierarchyTests`, or add source-hygiene tests.

- [ ] Add tests/source checks proving Program Monitor no longer repeats `StatusBadge(monitorStateLabel...)`, no longer renders `monitorDisplayMode`, and keeps the current/next strip inside the monitor deck.
- [ ] Move `monitorInlineStatusRow` into `previewDeck` using a top overlay with monitor-safe text colors.
- [ ] Remove the card-header status badge and top-right display-mode pill.
- [ ] Add a wallpaper import button in the empty wallpaper state, reusing the existing picker path.
- [ ] Keep CountPill unit style Chinese for wallpaper count.
- [ ] Remove the Run Queue empty-state card and keep one concise drop-zone instruction.
- [ ] Add low-emphasis footers to LeftPanel and LiveOpsPanel to reduce large empty tails.
- [ ] Run targeted tests, then full local verification.
- [ ] Open PR, wait for CI, squash merge on green.

## PR H: Live Ops Control Affordance

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Test: update or add LiveOps layout/source tests.

- [ ] Add tests/source checks proving mode rows use `Toggle`, BGM progress only renders with a current track, and output disabled styling does not apply whole-card opacity.
- [ ] Replace Speaker/PPT button rows with `Toggle` rows using a local `LiveOpsToggleStyle`.
- [ ] Keep accessibility labels `Speaker mode` and `PPT mode`, with values `On` or `Off`.
- [ ] Hide `bgmProgressRow` when `currentBGMItem == nil`.
- [ ] Replace output card disabled opacity with readable disabled button colors.
- [ ] Run targeted tests, then full local verification.
- [ ] Open PR, wait for CI, squash merge on green.

## PR I: Overlay Button Hierarchy and Type Scale

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Test: update `OverlayLivePreviewModelTests`, `OverlayUIStateTests`, or add source-level tests.

- [ ] Add tests/source checks proving disabled Send Live keeps a dimmed primary tint, Stop keeps a dimmed secondary tint, empty preview uses compact sizing, and composer title uses `StudioTheme.TypeScale.title`.
- [ ] Change `overlayActionButton` disabled fill to `fill.opacity(0.25)` and disabled text to `.white.opacity(0.55)`.
- [ ] Make `livePreviewColumn` use compact width/height when `OverlayLivePreviewModel.layers.isEmpty`.
- [ ] Replace hard-coded 24pt composer title with `StudioTheme.TypeScale.title`.
- [ ] Move `StudioTheme.numeric()` into `StudioTheme.TypeScale.numeric` and replace call sites.
- [ ] Run targeted tests, then full local verification.
- [ ] Open PR, wait for CI, squash merge on green.

## Verification For Every PR

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
- CI: wait for GitHub Smoke Tests, then squash merge if green.
