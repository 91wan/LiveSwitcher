# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.

Current authoritative runtime domains:
- Audio
- Media playback
- BGM playback and progress timer

Program queue, Panic, PPT, Projection, and Automation are not runtime-owned.
Their runtime state is either a ViewModel-owned snapshot or an explicit callback
from an already-executed facade path. Operator actions for unowned domains must
not mutate real domain state or infer playback/output state that the ViewModel
has not synchronized into the runtime snapshot.

## Production Bridge Mode

Production bridge mode is `.bgmOwned`.
`.fullRuntime` remains test-only; production BGM ownership is expressed by `.bgmOwned`.
Tests must use explicit bridge mode; full-runtime behavior must use the named
full-runtime test factory or `.fullRuntimeForTests(...)`.
`LiveRuntimeEnvironment()` must not imply production-unsafe full runtime.

Bridge modes are cumulative migration stages, not isolated domain selectors.
Each stage includes all domains migrated in earlier stages:

| Bridge mode | Runtime-owned domains |
| --- | --- |
| `recordingOnly` | none |
| `audioOwned` | Audio |
| `mediaOwned` | Audio, Media playback |
| `bgmOwned` | Audio, Media playback, BGM |
| `projectionOwned` | Audio, Media playback, BGM, Projection |
| `fullRuntime` | all runtime domains, test-only until deliberately approved |

`.bgmOwned` means Audio + Media + BGM, not Audio + BGM. `.projectionOwned`
means Audio + Media + BGM + Projection.

In this mode the runtime reducer owns `state.audio`, `state.media`, and
`state.bgm`, and may execute the wired ports needed for current production
behavior. Connected production ports: `media`, `bgm`, `bgmTimer`,
`audioRouting`, `imageAssets`, and `persistence`. The audio routing port is wired.
Audio routing context is stored inside `AudioRuntimeState`, so routing inputs
from mirror-only domains can be used without making Panic runtime-owned.

The reducer may record operator intent in the action log, but operator actions
for mirror-only domains must not change Projection, PPT, Panic, Program, or
Automation state. Mirror state changes for those domains must come from facade
synchronization or explicit callback actions such as media playback callbacks
and PPT event-tap callbacks.

Support storage uses runtime state, but production ingress remains
`ViewModel.recordSupportEvent` until a dedicated Support migration PR. In every
production bridge stage before explicit Support ownership, reducer-generated
support events are blocked except for the explicit `.supportEventRecorded`
action.
`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state.
Effective audio output getters are pure Runtime state reads.

A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed.
Operator actions for mirror-only domains must not mutate real runtime domain state.
No next domain may be migrated until the Audio, Media, and BGM ownership tests
pass and production effective audio output plus media/BGM playback output remain
runtime-owned. Projection/PPT migration remains blocked until BGM hardening
tests pass, its ports are wired, and an ownership PR is approved.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | ViewModel owner | Snapshot and action log | not migrated | ViewModel owns queue mutation, source validation, and non-media activation. Runtime may mirror current selection only to drive media playback. |
| Media playback | Runtime owner | Authoritative loaded URL, play/pause, restart, stop, seek, ended state, generation, and media effects | authoritative | Runtime emits `MediaPlaybackPort` effects; ViewModel bridges those effects to `AVPlayerCoordinator`. |
| BGM | Runtime owner | Authoritative current track, playback state, seek, loop-mode player side effects, progress, duration, generation, timer effects, and persisted play-mode preference | authoritative | Runtime emits `BGMPlaybackPort` and `BGMTimerPort` effects; ViewModel bridges those effects to `AVAudioPlayer`/`AVPlayer` and the progress timer. `saveBGMPlayMode` is a BGM-domain effect. BGM library editing remains ViewModel-owned. |
| Audio routing | Runtime owner | Authoritative audio state and routing decisions | authoritative | Audio faders, mutes, strategy, speaker mode, takeover, routing context, and effective output are runtime-owned. |
| Panic | ViewModel owner | Mirror-only snapshot plus runtime media/BGM pause/resume actions | not migrated | Panic orchestration remains ViewModel-owned; media and BGM pause/resume go through Runtime actions. |
| PPT mode | ViewModel owner | Mirror-only callback state and action log | recording only | Operator toggles do not mutate PPT state; event-tap started/failed/stopped callbacks may update the mirror. |
| Projection | ViewModel owner | Mirror-only snapshot/callback state | not migrated | Output windows and display safety remain ViewModel-owned. |
| Automation notice | ViewModel owner | Mirror-only notice state | not migrated | AppleScript execution and notice UI ownership remain ViewModel-owned. |
| Persistence | ViewModel/UserDefaults | Wired preference persistence effects | bridge in progress | Runtime may persist selected preferences, but general state save remains ViewModel/UserDefaults-owned. |

## Effect Wiring

| Port | Production state | Ownership meaning |
| --- | --- | --- |
| `media` | wired | Runtime media playback effects execute through the ViewModel bridge to `AVPlayerCoordinator`. |
| `bgm` | wired | Runtime BGM playback effects execute through the ViewModel bridge to `AVAudioPlayer` with an `AVPlayer` fallback. |
| `bgmTimer` | wired | Runtime BGM timer effects start and stop the ViewModel-owned timer implementation by generation. |
| `audioRouting` | wired | Runtime audio routing decisions execute through the ViewModel bridge using runtime state. |
| `imageAssets` | wired | Runtime can request background and corner-logo image reloads. |
| `persistence` | wired | Runtime can persist selected preference updates. |
| `projection` | not migrated | Projection effects are not executable in production. |
| `ppt` | recording only | Runtime does not start or stop the PPT event tap in production. |
| `automation` | not migrated | AppleScript execution is still ViewModel-owned. |
| `automationNotice` | recording only | Runtime records notice state while ViewModel drives the UI. |
| `support` | runtime storage, ViewModel ingress | Support events are stored in runtime state, but production writes enter through `ViewModel.recordSupportEvent`. |

## Media Playback Boundary

Media playback is runtime-owned. ViewModel validates sources, owns the program
queue, and sets UI-facing current program state, but media load/play/pause/
restart/stop/seek effects execute through `MediaPlaybackPort`. Seek-to-start and
seek-to-end are distinct runtime actions; restart remains the only migrated
operator action that seeks to the beginning and starts playback.

Media startup sets media volume to zero before loading so the Runtime audio
routing fade can bring the channel to the target level without a one-frame
burst. Runtime media callbacks are accepted only when the ViewModel still has an
active runtime media generation, the current program is media, and
`AVPlayerCoordinator.currentURL` matches the active runtime media URL. Accepted
callbacks dispatch runtime actions with the active generation. Stale effects are
also ignored by generation in the effect runner.

Media-owned program selection must not mutate PPT mirror state and must not own
non-media activation. PPT mirror state changes only through
`pptEventTapStarted`, `pptEventTapFailed`, and `pptEventTapStopped`.

## BGM Playback Boundary

BGM playback is runtime-owned. ViewModel owns BGM library import, removal,
category metadata, and ordering, but current track, play/stop/next/previous,
seek-to-beginning, seek-to-progress, loop-mode player side effects,
end/failure callbacks, progress, duration, generation, and timer start/stop are
owned by `LiveRuntimeState.bgm`.

Production uses `BGMPlaybackPort` and `BGMTimerPort` effects for concrete
playback and timer operations. ViewModel bridges those effects to
`AVAudioPlayer`, the `AVPlayer` fallback, and the existing timer implementation.
Runtime BGM effects are generation-guarded so stale play, stop, timer, progress,
finish, and failure callbacks cannot mutate the current track. Panic selection
can cue a BGM item without starting audible playback; Panic orchestration itself
remains ViewModel-owned.

BGM callbacks require an active runtime BGM generation plus active item identity:
the current BGM item id and URL must match the active callback guard before a
finish, failure, or progress callback can dispatch into Runtime. Callback
dispatch returns whether Runtime accepted the callback and must not fall back to
`runtime.state.bgm.generation`. Ignored stale BGM callbacks must not record
support events or playback-state support entries.

BGM timers are generation-bound. Runtime paths start and stop timers with
`startBGMTimer(generation:)` and `stopBGMTimer(generation:)`; stale stop
requests cannot stop the current timer.

BGM async cleanup has two separate ownership rules. Current-player tasks that
touch shared state such as `bgmAudioPlayer`, `bgmFallbackPlayer`, observers,
meters, active callback identity, timers, or effective output volume are
generation-guarded. Retired captured-player cleanup tasks are not skipped just
because a later BGM generation exists: old `AVAudioPlayer` instances and retired
fallback `AVPlayer` instances must finish fade/stop/release cleanup, remove only
their own retired-player bookkeeping, and must not touch the current player or
current fallback state.

BGM library editing remains ViewModel-owned. Runtime receives the facade
snapshot of library items so it can choose current/next/previous playback, but
it must not import, reorder, dedupe, or edit BGM metadata.

## Next Migration Gate

Projection, PPT, Program queue, Automation, and Support ingress migration remain
blocked. The next migration may proceed only after Audio, Media, and BGM
ownership and hardening tests pass, cumulative bridge tests pass, bridge mode
explicitness tests pass, no implicit full runtime remains, the target domain
port is connected in a dedicated PR, and ViewModel no longer owns that target
domain's migrated side effects in that future PR.
