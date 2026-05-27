# Observable Migration RFC

## Purpose

Round 9 identifies the remaining performance risk in the console state model:
`SwitcherViewModel` still uses `ObservableObject` with broad `@Published`
invalidations. This RFC records the current baseline and the migration plan
before any production migration happens.

This Phase 1 PR does not migrate `SwitcherViewModel`. It creates the profiling
baseline, risk register, and split plan needed for a separate PR that can safely
introduce `@Observable final class SwitcherViewModel`.

## Current Static Baseline

Measured on the current main baseline:

- `SwitcherViewModel` has 52 `@Published` properties.
- The app source has 25 direct `SwitcherViewModel` observation declarations
  through `@EnvironmentObject` or `@ObservedObject`.
- Previews and sample views add 7 preview or sample `.environmentObject(SwitcherViewModel())` injections.
- `xcrun xctrace list templates` includes `SwiftUI Profiler` coverage through
  the `SwiftUI` template, plus `Time Profiler` and `Animation Hitches`.

This means a change to countdown, ticker, BGM playback state, panic state,
speaker mode, program queue state, or output state can still invalidate large
parts of the console tree even when a narrow panel is the only consumer.

## Phase 1 Profiling Scenarios

Use Instruments with the SwiftUI template. Record the body update counts,
main-thread time, and visible interaction latency for each scenario.

| Scenario | Setup | Action | Capture Window | Metrics |
| --- | --- | --- | --- | --- |
| Drag Master fader for 1 second | Launch app in setup or live mode with one media item and BGM library loaded. | Drag the Master volume slider continuously for 1 second. | Start recording before drag, stop 2 seconds after release. | SwiftUI body updates, main-thread work, slider latency. |
| Switch current program item | Queue two media items. First item selected, second item next. | Trigger next item from live mode. | Start recording before trigger, stop after monitor state settles. | Body updates in source rail, monitor, live ops, output layers. |
| BGM playback for 10 seconds | Select a BGM item and keep app in Audio or Live mode. | Play BGM without touching controls. | Record 10 seconds of steady playback. | Body updates caused by progress and meter paths. |
| Countdown reaches 0 | Configure a short countdown overlay. | Send countdown live and wait until it reaches 0. | Record the full countdown and 2 seconds after completion. | Body updates from countdown timer and overlay views. |

Recommended local commands for the profiling session:

```bash
swift build
./script/build_and_run.sh --verify
xcrun xctrace list templates | rg "SwiftUI|Time Profiler|Animation Hitches"
```

The actual Instruments recordings are manual acceptance artifacts because the
four scenarios require operator interactions. Attach trace summaries to the
Phase 2 PR before changing observation semantics.

## Views That Should Stop Observing The Whole ViewModel

The migration should keep user-facing behavior stable while narrowing
observation scope. Candidate split areas:

- Program runtime state: current item, next item, queue position, monitor badge,
  restart-current-media availability.
- Audio runtime state: master/media/BGM fader values, effective output values,
  speaker/panic limiters, routing strategy summary.
- BGM library/playback state: selected category, current track, transport
  availability, progress model, playlist rows.
- Overlay live state: lower-third/countdown/ticker live flags, active stack,
  composer draft state.
- Preflight/support state: fail/warn summary, action routing, support events.
- Wallpaper and corner-logo asset state: active wallpaper, cached thumbnails,
  corner logo image, corner logo position.

## Proposed Migration Boundary

Phase 2 should be a separate PR with one migration boundary:

1. Convert `SwitcherViewModel` to `@Observable final class SwitcherViewModel`.
2. Replace top-level `@StateObject` ownership with stable `@State` ownership at
   the app entry point.
3. Replace `@EnvironmentObject` and `@ObservedObject` `SwitcherViewModel`
   consumers with Observation-based access.
4. Preserve existing `didSet` persistence and side effects.
5. Keep BGMProgressStore and other existing stores intact unless a compiler
   issue forces a narrow compatibility change.
6. Re-run the four SwiftUI Profiler scenarios and compare against this RFC.

Phase 2 must not combine this migration with UI redesign, routing changes, BGM
transition changes, or release version changes.

## Acceptance Gates For Phase 2

- Drag Master fader body updates fall by at least 50 percent compared with the
  Phase 1 trace.
- BGM playback for 10 seconds no longer invalidates the full console tree.
- Countdown reaches 0 without invalidating unrelated Audio and BGM library
  surfaces every tick.
- Switching current program item keeps Live mode responsive and does not reset
  setup tab state.
- Existing test suites remain green.
- Manual screenshot acceptance confirms Run, Audio, Overlays, and Live mode
  still render with the current information hierarchy.

## Risks And Rollback

- `@State var viewModel = SwitcherViewModel()` must preserve reference identity
  across the app window lifecycle.
- Combine pipelines inside `SwitcherViewModel` may rely on `ObservableObject`
  conventions. Preserve the pipelines first; remove only truly obsolete
  `objectWillChange` behavior after tests and traces are green.
- Preview injection sites need a consistent replacement so SwiftUI previews do
  not drift from production setup.
- If Phase 2 does not improve the four scenario traces enough, roll back the
  migration PR and continue with narrower store extraction.
