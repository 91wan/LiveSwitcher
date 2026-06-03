# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.

Current authoritative runtime domains:
- Audio
- Media playback

Program queue, BGM, Panic, PPT, Projection, and Automation are mirror-only.
Their runtime state is a snapshot of ViewModel-owned reality or a callback from
an already-executed facade path. Operator actions for mirror-only domains must
not mutate real runtime domain state or infer playback/output state that the
ViewModel has not already synchronized into the runtime snapshot.

## Production Bridge Mode

Production uses `LiveRuntimeBridgeMode.mediaOwned`.
Production bridge mode is `.mediaOwned`.
`.fullRuntime` remains test-only; production media ownership is expressed by `.mediaOwned`.
Tests must use explicit bridge mode; full-runtime behavior must use the named
full-runtime test factory or `.fullRuntimeForTests(...)`.
`LiveRuntimeEnvironment()` must not imply production-unsafe full runtime.

In this mode the runtime reducer owns `state.audio` and `state.media`, and may execute the wired
ports needed for current production behavior. Connected production ports: `media`, `audioRouting`, `imageAssets`, and `persistence`. The audio routing port is wired.
Audio routing context is stored inside `AudioRuntimeState`, so routing inputs
from mirror-only domains can be used without making BGM or Panic runtime-owned.

The reducer may record operator intent in the action log, but operator actions
for mirror-only domains must not change BGM, Projection, PPT, Panic,
Program, or Automation state. Mirror state changes for those domains must come
from facade synchronization or explicit callback actions such as media/BGM
playback callbacks and PPT event-tap callbacks.

Support storage uses runtime state, but production ingress is
`ViewModel.recordSupportEvent`. In `.mediaOwned`, reducer-generated support
events are blocked except for the explicit `.supportEventRecorded` action.
`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state.
Effective audio output getters are pure Runtime state reads.

A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed.
Operator actions for mirror-only domains must not mutate real runtime domain state.
No next domain may be migrated until the Audio and Media ownership tests pass and
production effective audio output and media playback output remain runtime-owned.
BGM/Projection/PPT migration is blocked until its ports are wired and an ownership PR is approved.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | ViewModel owner | Mirror-only snapshot and action log | not migrated | ViewModel owns queue mutation and source validation; runtime may mirror current selection for media playback. |
| Media playback | Runtime owner | Authoritative loaded URL, play/pause, restart, stop, ended state, generation, and media effects | authoritative | Runtime emits `MediaPlaybackPort` effects; ViewModel bridges those effects to `AVPlayerCoordinator`. |
| BGM | ViewModel owner | Mirror-only snapshot/callback state plus persisted play-mode preference | not migrated | Concrete playback, current track, progress, and timer ownership remain in ViewModel. |
| Audio routing | Runtime owner | Authoritative audio state and routing decisions | authoritative | Audio faders, mutes, strategy, speaker mode, takeover, routing context, and effective output are runtime-owned. |
| Panic | ViewModel owner | Mirror-only snapshot plus runtime media pause/resume actions | not migrated | Panic orchestration and BGM behavior remain ViewModel-owned; media pause/resume goes through Runtime. |
| PPT mode | ViewModel owner | Mirror-only callback state and action log | recording only | Operator toggles do not mutate PPT state; event-tap started/failed/stopped callbacks may update the mirror. |
| Projection | ViewModel owner | Mirror-only snapshot/callback state | not migrated | Output windows and display safety remain ViewModel-owned. |
| Automation notice | ViewModel owner | Mirror-only notice state | not migrated | AppleScript execution and notice UI ownership remain ViewModel-owned. |
| Persistence | ViewModel/UserDefaults | Wired preference persistence effects | bridge in progress | Runtime may persist selected preferences, but general state save remains ViewModel/UserDefaults-owned. |

## Effect Wiring

| Port | Production state | Ownership meaning |
| --- | --- | --- |
| `media` | wired | Runtime media playback effects execute through the ViewModel bridge to `AVPlayerCoordinator`. |
| `audioRouting` | wired | Runtime audio routing decisions execute through the ViewModel bridge using runtime state. |
| `imageAssets` | wired | Runtime can request background and corner-logo image reloads. |
| `persistence` | wired | Runtime can persist selected preference updates. |
| `bgm` | not migrated | BGM playback effects are not executable in production. |
| `projection` | not migrated | Projection effects are not executable in production. |
| `ppt` | recording only | Runtime does not start or stop the PPT event tap in production. |
| `automation` | not migrated | AppleScript execution is still ViewModel-owned. |
| `automationNotice` | recording only | Runtime records notice state while ViewModel drives the UI. |
| `bgmTimer` | not migrated | BGM timer effects are not executable in production. |
| `support` | runtime storage, ViewModel ingress | Support events are stored in runtime state, but production writes enter through `ViewModel.recordSupportEvent`. |

## Media Playback Boundary

Media playback is runtime-owned. ViewModel validates sources, owns the program
queue, and sets UI-facing current program state, but media load/play/pause/
restart/stop effects execute through `MediaPlaybackPort`. Media startup sets
media volume to zero before loading so the Runtime audio routing fade can bring
the channel to the target level without a one-frame burst. AVPlayer callbacks
dispatch Runtime actions and stale media effects are ignored by generation.

## Next Migration Gate

The next migration may be BGM, Projection, or PPT only after Audio and Media
ownership tests pass, bridge mode explicitness tests pass, no implicit full
runtime remains, the target domain port is connected in a dedicated PR, and
ViewModel no longer owns that target domain's migrated side effects in that
future PR.
