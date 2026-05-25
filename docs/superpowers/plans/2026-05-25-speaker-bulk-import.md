# Speaker Bulk Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let enterprise-event operators import lower-third speaker presets from CSV/TSV/text or clipboard instead of creating every speaker manually.

**Architecture:** Add a pure `SpeakerImportService` for decoding, parsing, conflict resolution, and CSV export. Add ViewModel import/export helpers so SwiftUI and App commands share one state path, while UI code only handles panels, alerts, clipboard, and save/open dialogs.

**Tech Stack:** SwiftPM macOS app, Swift/SwiftUI/AppKit, XCTest.

---

### Task 1: Import Engine

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Engines/SpeakerImportService.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SpeakerImportServiceTests.swift`

- [ ] Write failing tests for UTF-8/GB18030 data decoding, CSV/TSV/single-column parsing, quoted fields, whitespace trimming, empty row skipping, duplicate policies, and CSV export.
- [ ] Run `swift test --filter SpeakerImportServiceTests` and verify failures because `SpeakerImportService` is missing.
- [ ] Implement `SpeakerImportService` with `parse(data:)`, `parse(text:)`, `merge(imported:existing:policy:)`, and `exportCSV(_:)`.
- [ ] Re-run `swift test --filter SpeakerImportServiceTests` and verify all focused tests pass.

### Task 2: ViewModel Import Path

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Overlay.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SpeakerImportServiceTests.swift`

- [ ] Add tests that `SwitcherViewModel.importLowerThirdPresets` persists imported speakers, skips duplicates by default, overwrites matching names when requested, and preserves selected draft state.
- [ ] Run focused tests and verify failures because the ViewModel helper is missing.
- [ ] Implement the ViewModel helper using `SpeakerImportService.merge`.
- [ ] Re-run focused tests and verify green.

### Task 3: Overlay UI, Clipboard, And Export

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/App.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/OverlayLivePreviewModelTests.swift`

- [ ] Add source-level tests that the lower-third preset shelf exposes `Import...` and `Export...`, uses `NSOpenPanel`/`NSSavePanel`, and App exposes `Paste Speakers from Clipboard` with `⌘⇧V`.
- [ ] Run focused tests and verify failures against the existing UI.
- [ ] Add Import and Export buttons to Lower Third Presets, with file preview confirmation and duplicate policy handling through `NSAlert`.
- [ ] Add `Edit -> Paste Speakers from Clipboard` command that parses `NSPasteboard.general` and imports through the ViewModel.
- [ ] Re-run focused tests and verify green.

### Task 4: Full Verification And PR

**Files:**
- All changed files above.

- [ ] Run `swift build`.
- [ ] Run `swift test`.
- [ ] Run `cd Sources/AnnualMeetingSwitcher && swift test`.
- [ ] Run `git diff --check`.
- [ ] Run `./script/check_release_hygiene.sh`.
- [ ] Run `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`.
- [ ] Run `./script/build_and_run.sh --verify`.
- [ ] Run `bash Sources/AnnualMeetingSwitcher/build_v33.sh`.
- [ ] Run `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`.
- [ ] Run `codesign --verify --deep --strict dist/LiveSwitcher.app`.
- [ ] Use Computer Use screenshot/app-tree acceptance on Setup Overlays to verify Import/Export controls are visible without layout breakage.
- [ ] Commit, open PR, wait for GitHub CI, and squash merge when green.

## Acceptance
- CSV, TSV, and pasted text with `name,title` rows create lower-third presets.
- UTF-8 and Chinese Excel GB18030/GBK-style data decode correctly.
- Empty rows and trailing whitespace are ignored.
- Same-name conflicts default to skip, with overwrite and import-all policies available.
- The lower-third preset shelf exposes Import and Export controls.
- The app exposes `Paste Speakers from Clipboard` through the Edit command group with `⌘⇧V`.
- Existing Live mode lower-third preset behavior remains untouched.
