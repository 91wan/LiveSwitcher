# LiveSwitcher UI Overhaul Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the Claude UI-overhaul review in small, mergeable PRs without changing core playback, projection, or audio routing behavior.

**Architecture:** Work as five sequential PR slices. First remove unused UI code so later token and IA changes do not preserve dead branches; then reset UI tokens; then tighten the top chrome; then simplify Run Desk controls; finally make Overlay Preview match active output state.

**Tech Stack:** Swift 5.9, SwiftPM macOS 14 app, SwiftUI, XCTest, GitHub Actions smoke tests.

---

## PR A: Remove Dead UI Code And Move Business Enums

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/AudioStrategy.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/BGMCategory.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/BGMPlaylistPanel.swift`
- Delete: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RightPanel.swift`
- Modify tests under `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/`

- [x] Write/adjust source hygiene tests so `RightPanel.swift`, `BGMPlaylistPanelMode`, and `.liveDock` are absent.
- [x] Move `AudioStrategy` into `Models/AudioStrategy.swift`, preserving current stable ASCII raw values and legacy Chinese migration.
- [x] Move `BGMCategory` into `Models/BGMCategory.swift`, preserving existing Chinese category raw values.
- [x] Move `BGMItemRow` into `BGMPlaylistPanel.swift`, then delete `RightPanel.swift`.
- [x] Remove `BGMPlaylistPanelMode`, `mode`, live-dock layout branches, and live-dock-only auto category sync from `BGMPlaylistPanel`.
- [x] Run `swift build`, `swift test`, child package `swift test`, hygiene checks, app verify, bundle build, plist lint, and codesign.
- [x] Open PR, wait for CI, merge on green.

## PR B: Reset StudioTheme Tokens Without IA Layout Changes

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Modify: SwiftUI files that reference old token names.
- Add/modify: `StudioThemeTokenContractTests.swift`

- [x] Add failing token contract tests for nested `Tone`, `Action`, `Surface`, `Spacing`, `Radius`, and `TypeScale`.
- [x] Introduce nested token namespaces and `StudioTheme.color(for:)`.
- [x] Replace old color/surface/spacing/radius/font references across app sources.
- [x] Remove decorative `accent`, `accentSecondary`, `green`, `orange`, `pink`, `actionDanger`, and old surface constants from app view usage.
- [x] Convert common magic opacity values to `StudioTheme.Surface.Opacity`.
- [x] Run full local verification, open PR, wait for CI, merge on green.

## PR C: Collapse Top Chrome And Add Preflight Counts

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Modify/add tests for top chrome, preflight badge, and monitor inline status.

- [x] Add tests that `ContentView` no longer owns `LiveStatusStrip`, the static `Run Desk` subtitle is removed, and `MainConsoleTab` supplies the dynamic title.
- [x] Add tests that Preflight badge text includes fail/warn counts.
- [x] Replace the two-line navigation title with one-line `LiveSwitcher · <current tab>`.
- [x] Remove `LiveStatusStrip` and move its accessibility summary into Program Monitor inline status.
- [x] Replace Current/Next cards with a compact monitor inline status row.
- [x] Run full local verification, open PR, wait for CI, merge on green.

## PR D: Simplify Run Desk IA Controls

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/BGMControlsState.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Modify/add Run Desk model/source tests.

- [x] Add tests for no `DisclosureGroup` in Program Monitor utilities and no standalone Modes card in Live Ops.
- [x] Add tests for four visible Add Source actions and neutral Auto-next idle styling.
- [x] Add tests that BGM idle status is `IDLE` or `OFF`, not `SELECT`.
- [x] Inline Transition and Wallpaper controls below the monitor instead of default-collapsed Utilities.
- [x] Merge Speaker/PPT toggles into LiveOps Audio card and keep Output/Audio/BGM as the only top cards.
- [x] Replace Add Source menu with a 2x2 button grid.
- [x] Neutralize Auto-next icon/color when off; make scan refresh non-focusable.
- [x] Set `directorRailWidth` to 320 after verifying layout.
- [x] Run full local verification, open PR, wait for CI, merge on green.

## PR E: Make Overlay Preview WYSIWYG And Unify Overlay CTAs

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayLivePreviewCanvas.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Add/modify overlay tests.

- [x] Add model/source tests that all-off preview does not render active overlay text and active states render matching layers.
- [x] Create `OverlayLivePreviewCanvas` that uses real overlay state and draft overlays at reduced opacity.
- [x] Replace hand-written always-on preview functions in `OverlayControlPanel`.
- [x] Use `StudioTheme.Action.primary` for all Send Live buttons and neutral secondary styling for Stop.
- [x] Allow replacing live overlays via Send Live text/state without ViewModel changes.
- [ ] Run full local verification, open PR, wait for CI, merge on green.

## Final Sweep

- [ ] Re-read the local Claude UI-overhaul review brief and map each A-E requirement to merged commits.
- [ ] Run the full required verification chain on latest `main`.
- [ ] Confirm no open PRs and `main` CI is green.
- [ ] Report merged PRs, verification evidence, and any deliberately deferred backlog items from the review document.
