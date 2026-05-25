# Agenda Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional agenda timing to Run Queue so company-event operators can see schedule ranges and schedule drift without replacing the existing queue workflow.

**Architecture:** Extend `ProgramItem` with optional schedule metadata and persist it alongside the existing queue arrays. Add pure agenda models for inferred timelines, live schedule status, and scheduled-time prompts, then wire small Setup/Live UI affordances to those models.

**Tech Stack:** SwiftPM macOS app, SwiftUI, Foundation Date/TimeInterval, XCTest, existing UserDefaults queue persistence.

---

### Task 1: Schedule Data And Models

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramSourceKind.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/AgendaTimelineModel.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AgendaTimelineModelTests.swift`

- [x] Write failing tests for optional schedule defaults, inferred timeline ranges, marker items, live behind/ahead/on-schedule status, scheduled prompt logic, and persistence round-trip.
- [x] Run `swift test --filter AgendaTimelineModelTests` and verify failures because agenda types and fields are missing.
- [x] Add `scheduledStartAt`, `scheduledDuration`, agenda marker helpers, schedule persistence arrays, and pure agenda models.
- [x] Re-run focused tests and verify green.

### Task 2: Run Queue Agenda UI

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift`
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AgendaTimelineView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AgendaTimelineModelTests.swift`

- [x] Add source-level tests for `AgendaTimelineView`, `AgendaScheduleEditorPopover`, `showAgendaTimeline`, `autoAdvanceAtScheduledTime`, and row schedule text.
- [x] Run focused tests and verify failures.
- [x] Add Setup toggles for queue/timeline and scheduled prompt mode, schedule edit popover on rows, marker creation, and the vertical agenda timeline list.
- [x] Re-run focused tests and verify green.

### Task 3: Live Schedule Status

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LivePreflight.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Preflight.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LiveModeRuntimeModels.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AgendaTimelineModelTests.swift`

- [x] Add tests that live runtime chips show `On schedule`, `Behind by N min`, and `Ahead N min`.
- [x] Run focused tests and verify failures.
- [x] Add current schedule fields to the preflight snapshot and append the agenda chip in live runtime status.
- [x] Re-run focused tests and verify green.

### Task 4: Full Verification And PR

- [x] Run `swift build`.
- [x] Run `swift test`.
- [x] Run `cd Sources/AnnualMeetingSwitcher && swift test`.
- [x] Run `git diff --check`.
- [x] Run `./script/check_release_hygiene.sh`.
- [x] Run `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`.
- [x] Run `./script/build_and_run.sh --verify`.
- [x] Run `bash Sources/AnnualMeetingSwitcher/build_v33.sh`.
- [x] Run `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist`.
- [x] Run `codesign --verify --deep --strict dist/LiveSwitcher.app`.
- [x] Use Computer Use screenshot/app-tree acceptance on Setup Run and Live mode.
- [ ] Commit, open PR, wait for GitHub CI, and squash merge when green.

## Acceptance
- Existing queues without schedule metadata behave the same as before.
- Scheduled items show optional `HH:mm-HH:mm` ranges in Run Queue rows.
- Agenda Timeline view coexists with the queue list and can infer unscheduled starts from previous item endings.
- Markers are non-playable agenda entries.
- Live mode exposes schedule drift as `On schedule`, `Behind by N min`, or `Ahead N min`.
- Scheduled auto-advance stays operator-confirmed; it only prompts and never cuts automatically.
