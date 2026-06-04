# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.

Current authoritative runtime domains:
- Audio
- Media playback
- BGM playback and progress timer
- Projection output
- PPT EventTap lifecycle

Program queue, Panic orchestration, and Automation are not runtime-owned.
PPT key forwarding and WPS automation implementation remain ViewModel-owned.
Their runtime state is either a ViewModel-owned snapshot or an explicit callback
from an already-executed facade path. Operator actions for unowned domains must
not mutate real domain state or infer playback/output state that the ViewModel
has not synchronized into the runtime snapshot.

## Production Bridge Mode

Production bridge mode is `.pptOwned`.
`.fullRuntime` remains test-only; production PPT lifecycle ownership is expressed by `.pptOwned`.
Tests must use explicit bridge mode; full-runtime behavior must use the named
full-runtime test factory or `.fullRuntimeForTests(...)`.
`LiveRuntimeEnvironment()` must not imply production-unsafe full runtime.
Explicit runtime-store construction rules:
- Bridge mode is explicit and never inferred from ports.
- Ports describe executable capabilities.
- Bridge mode describes domain ownership.
- A custom `LiveRuntimeEffectRunner` must always be paired with an explicit `LiveRuntimeEnvironment`.
- Connected ports such as `persistence` must not promote the store to a broader ownership mode.

Bridge modes are cumulative migration stages, not isolated domain selectors.
Each stage includes all domains migrated in earlier stages:

| Bridge mode | Runtime-owned domains |
| --- | --- |
| `recordingOnly` | none |
| `audioOwned` | Audio |
| `mediaOwned` | Audio, Media playback |
| `bgmOwned` | Audio, Media playback, BGM |
| `projectionOwned` | Audio, Media playback, BGM, Projection |
| `pptOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle |
| `fullRuntime` | all runtime domains, test-only until deliberately approved |

`.bgmOwned` means Audio + Media + BGM, not Audio + BGM. `.projectionOwned`
means Audio + Media + BGM + Projection. `.pptOwned` means Audio + Media + BGM
+ Projection + PPT EventTap lifecycle.

In this mode the runtime reducer owns `state.audio`, `state.media`,
`state.bgm`, `state.projection`, and PPT requested/active/failure state, and may
execute the wired ports needed for current production behavior. Connected
production ports: `media`, `bgm`, `bgmTimer`, `projection`, `ppt`,
`audioRouting`, `imageAssets`, and `persistence`. The audio routing,
projection, and PPT EventTap ports are wired.
Audio routing context is stored inside `AudioRuntimeState`, so routing inputs
from mirror-only domains can be used without making Panic runtime-owned.

The reducer may record operator intent in the action log, but operator actions
for mirror-only domains must not change Panic, Program, or Automation state.
Mirror state changes for those domains must come from facade synchronization or
explicit callback actions such as media playback callbacks. PPT EventTap
lifecycle changes flow through Runtime operator actions and callback actions.

Support storage uses runtime state, but production ingress remains
`ViewModel.recordSupportEvent` until a dedicated Support migration PR. In every
production bridge stage before explicit Support ownership, reducer-generated
support events are blocked except for the explicit `.supportEventRecorded`
action.
`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state.
Effective audio output getters are pure Runtime state reads.

A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed.
Operator actions for mirror-only domains must not mutate real runtime domain state.
No next domain may be migrated until the Audio, Media, BGM, Projection, and PPT
ownership tests pass and production effective audio output plus media/BGM
playback output plus projection start/stop output plus PPT EventTap lifecycle
remain runtime-owned. Automation and Support production ingress migration remain
blocked until a dedicated ownership PR is approved.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | ViewModel owner | Snapshot and action log | not migrated | ViewModel owns queue mutation, source validation, and non-media activation. Runtime may mirror current selection only to drive media playback. |
| Media playback | Runtime owner | Authoritative loaded URL, play/pause, restart, stop, seek, ended state, generation, and media effects | authoritative | Runtime emits `MediaPlaybackPort` effects; ViewModel bridges those effects to `AVPlayerCoordinator`. |
| BGM | Runtime owner | Authoritative current track, playback state, seek, loop-mode player side effects, progress, duration, generation, timer effects, and persisted play-mode preference | authoritative | Runtime emits `BGMPlaybackPort` and `BGMTimerPort` effects; ViewModel bridges those effects to `AVAudioPlayer`/`AVPlayer` and the progress timer. `saveBGMPlayMode` is a BGM-domain effect. BGM library editing remains ViewModel-owned. |
| Audio routing | Runtime owner | Authoritative audio state and routing decisions | authoritative | Audio faders, mutes, strategy, speaker mode, takeover, routing context, and effective output are runtime-owned. |
| Panic | ViewModel owner | Mirror-only snapshot plus runtime media/BGM pause/resume actions | not migrated | Panic orchestration remains ViewModel-owned; media and BGM pause/resume go through Runtime actions. |
| PPT mode | Runtime owner | Authoritative requested/active/failure state and EventTap lifecycle effects | authoritative | Runtime owns PPT mode request, active callback state, failure rollback, and `PPTEventTapPort` start/stop effects. ViewModel owns concrete CGEventTap fields, key forwarding, WPS automation implementation, permission alert UI, support event production, telemetry, and the `isPageInterceptEnabled` facade projection. |
| Projection | Runtime owner | Authoritative broadcast state, external-display availability, safety notice, display-loss timestamp, and start/stop effects | authoritative | Runtime owns projection start/stop decisions and emits canonical `ProjectionPort` effects. ViewModel owns the concrete `OutputWindowController`, target screen lookup, output view mounting, UI facade fields, support event production, and telemetry. |
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
| `projection` | wired | Runtime projection start/stop effects execute through the ViewModel bridge to the concrete output window controller. |
| `ppt` | wired | Runtime PPT EventTap lifecycle effects execute through the ViewModel bridge to the concrete CGEventTap implementation. |
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

## Projection Output Boundary

Projection output is runtime-owned. Runtime owns
`state.projection.isBroadcasting`, `hasExternalDisplay`, `safetyNotice`,
`lastDisplayLostAt`, and the start/stop decision for operator toggles and
external-display callbacks. The projection reducer emits only canonical
`.startProjection` and `.stopProjection` effects for operator toggles; it does
not pair them with `.showOutputWindow` or `.hideOutputWindow`.

Production uses `ProjectionPort` effects for output-window side effects.
ViewModel bridges those effects to `OutputWindowController`, `OutputView`
mounting, and `ProjectionService` screen lookup. The concrete output window
controller remains behind the projection port and is not runtime-owned.
Raw output-window show/hide side effects are internal ProjectionPort
implementation details and must not be exposed as direct ViewModel bypasses.

Projection start failure is distinct from display loss.
`projectionStartFailed` records start failure semantics when the operator tries
to start projection but no target screen is available. It sets the start-failed
safety notice and does not emit `stopProjection`.
`projectionExternalDisplayLost` is only for broadcasting loss after projection
was already active; it sets the display-lost safety notice and emits
`stopProjection` only when the previous state was broadcasting.

Support production ingress remains ViewModel-owned. In `.projectionOwned`,
projection reducer actions must not write support storage directly; support
entries for projection start, stop, fail-closed, and display-lost events are
recorded by ViewModel after Runtime transitions. `.supportEventRecorded` remains
the only reducer action that writes support storage in production.

## PPT EventTap Boundary

PPT EventTap lifecycle is runtime-owned. Runtime owns `state.ppt.isRequested`,
`state.ppt.isEventTapActive`, `state.ppt.lastFailureReason`, operator set/toggle
decisions, and `startPPTEventTap` / `stopPPTEventTap` effects. The UI facade
`isPageInterceptEnabled` is a projection from `state.ppt.isEventTapActive`, so
PPT appears ON only after the EventTap started callback is accepted.

Production uses `PPTEventTapPort` effects for EventTap lifecycle side effects.
ViewModel bridges those effects to the existing CGEventTap fields:
`pageInterceptEventTap`, `pageInterceptRunLoopSource`, and
`pageInterceptSelfRefcon`. The actual key forwarding, WPS/Keynote automation,
permission alert UI, telemetry, and PPT support event production remain
ViewModel-owned.

PPT start success records support only after `pptEventTapStarted`. PPT start
failure dispatches `pptEventTapFailed`, rolls back requested and active state,
keeps the facade OFF, records failure support only, and must not record
`pptModeChanged isOn=true`. PPT stop dispatches `pptEventTapStopped` and records
OFF support once after Runtime state is known. In `.pptOwned`, PPT reducer
actions must not write support storage directly; `.supportEventRecorded` remains
the only reducer action that writes support storage in production.

## Next Migration Gate

Program queue, Automation, and Support ingress migration remain blocked.
The next migration may proceed only after Audio, Media, BGM, Projection, and PPT
ownership and hardening tests pass, cumulative bridge tests pass, bridge mode
explicitness tests pass, explicit runtime-store tests pass, no implicit full
runtime remains, the target domain port is connected in a dedicated PR, and
ViewModel no longer owns that target domain's migrated side effects in that
future PR. Support production ingress remains ViewModel-owned until a dedicated
Support ownership PR.
Automation migration remains blocked.

Remaining migration boundaries:
- PPT key forwarding and WPS automation implementation remain ViewModel-owned.
- Automation is not runtime-owned yet.
- Support production ingress remains ViewModel-owned.
