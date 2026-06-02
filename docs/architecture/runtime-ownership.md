# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.

Current authoritative runtime domain: Audio only.

Program, Media, BGM, Panic, PPT, Projection, and Automation are mirror-only.
Their runtime state is a snapshot of ViewModel-owned reality or a callback from
an already-executed facade path. Operator actions for mirror-only domains must
not mutate real runtime domain state or infer playback/output state that the
ViewModel has not already synchronized into the runtime snapshot.

## Production Bridge Mode

Production uses `LiveRuntimeBridgeMode.audioOwned`.

In this mode the runtime reducer owns `state.audio` and may execute the wired
ports needed for current production behavior. Connected production ports: `audioRouting`, `imageAssets`, and `persistence`. The audio routing port is wired.

The reducer may record operator intent in the action log, but operator actions
for mirror-only domains must not change Media, BGM, Projection, PPT, Panic,
Program, or Automation state. Mirror state changes for those domains must come
from facade synchronization or explicit callback actions such as media/BGM
playback callbacks and PPT event-tap callbacks.

Support storage uses runtime state, but production ingress is
`ViewModel.recordSupportEvent`. In `.audioOwned`, reducer-generated support
events are blocked except for the explicit `.supportEventRecorded` action.

A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed.
Operator actions for mirror-only domains must not mutate real runtime domain state.
No next domain may be migrated until the Audio ownership tests pass and
production effective audio output remains runtime-owned.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | ViewModel owner | Mirror-only snapshot and action log | not migrated | Operator program selection is logged, but runtime must not predict the current program in `.audioOwned`. |
| Media playback | ViewModel owner | Mirror-only snapshot/callback state | not migrated | Runtime may receive media callbacks, but operator playback/restart actions must not mutate media state in `.audioOwned`. |
| BGM | ViewModel owner | Mirror-only snapshot/callback state plus persisted play-mode preference | not migrated | Concrete playback, current track, progress, and timer ownership remain in ViewModel. |
| Audio routing | Runtime owner | Authoritative audio state and routing decisions | authoritative | Audio faders, mutes, strategy, speaker mode, takeover, and effective output are runtime-owned. |
| Panic | ViewModel owner | Mirror-only snapshot | not migrated | Panic shutdown/restore and support ingress remain ViewModel-owned in `.audioOwned`. |
| PPT mode | ViewModel owner | Mirror-only callback state and action log | recording only | Operator toggles do not mutate PPT state; event-tap started/failed/stopped callbacks may update the mirror. |
| Projection | ViewModel owner | Mirror-only snapshot/callback state | not migrated | Output windows and display safety remain ViewModel-owned. |
| Automation notice | ViewModel owner | Mirror-only notice state | not migrated | AppleScript execution and notice UI ownership remain ViewModel-owned. |
| Persistence | ViewModel/UserDefaults | Wired preference persistence effects | bridge in progress | Runtime may persist selected preferences, but general state save remains ViewModel/UserDefaults-owned. |

## Effect Wiring

| Port | Production state | Ownership meaning |
| --- | --- | --- |
| `audioRouting` | wired | Runtime audio routing decisions execute through the ViewModel bridge using runtime state. |
| `imageAssets` | wired | Runtime can request background and corner-logo image reloads. |
| `persistence` | wired | Runtime can persist selected preference updates. |
| `media` | not migrated | Media playback effects are not executable in production. |
| `bgm` | not migrated | BGM playback effects are not executable in production. |
| `projection` | not migrated | Projection effects are not executable in production. |
| `ppt` | recording only | Runtime does not start or stop the PPT event tap in production. |
| `automation` | not migrated | AppleScript execution is still ViewModel-owned. |
| `automationNotice` | recording only | Runtime records notice state while ViewModel drives the UI. |
| `bgmTimer` | not migrated | BGM timer effects are not executable in production. |
| `support` | runtime storage, ViewModel ingress | Support events are stored in runtime state, but production writes enter through `ViewModel.recordSupportEvent`. |

## Restart Boundary

Media restart is still split. The media restart effect is not executed by runtime yet; ViewModel still executes media restart through `programRestartFromBeginningHandler`. Runtime audio routing uses the synchronized snapshot and the authoritative runtime audio state.
