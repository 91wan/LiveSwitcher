# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.
Runtime authoritative: no. The runtime is still a migration boundary for most
live-console domains, not the single source of truth for the full app.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | ViewModel owner | Runtime mirror and action log | bridge in progress | Runtime can record operator-selected program actions, but ViewModel still owns queue mutation and activation. |
| Media playback | ViewModel plus partial runtime | Runtime mirror and audio-routing trigger | bridge in progress | Runtime can request `restartMedia`, but the media restart effect is not executed by runtime yet; ViewModel still executes media restart. |
| BGM | ViewModel owner | Runtime mirror only | not migrated | Runtime records BGM intent and persistence actions, while concrete playback/timer ownership remains in ViewModel. |
| Audio routing | Runtime effect to ViewModel bridge | Runtime owns routing decision and applies through the wired `audioRouting` port | bridge in progress | The audio routing port is wired; the ViewModel bridge still owns concrete player volume application. |
| Panic | ViewModel plus runtime mirror | Runtime mirrors panic state and routing changes | bridge in progress | Panic playback shutdown/restore still has ViewModel-owned pieces. |
| PPT mode | ViewModel owner | Runtime action log only | recording only | Runtime event-tap actions are callbacks from ViewModel. Runtime does not start or stop the PPT event tap in production. |
| Projection | ViewModel owner | Runtime mirror only | not migrated | Output windows and display loss handling still live in ViewModel. |
| Automation notice | ViewModel plus runtime mirror | Runtime records notice state | bridge in progress | Notice rendering and lifecycle sync remain ViewModel-owned. |
| Persistence | ViewModel/UserDefaults | Partial runtime persistence effects | bridge in progress | Several preferences are wired through runtime effects, but general state save remains ViewModel/UserDefaults-owned. |

## Effect Wiring

| Port | Production state | Ownership meaning |
| --- | --- | --- |
| `audioRouting` | wired | Runtime audio routing decisions are executed through the ViewModel bridge. |
| `imageAssets` | wired | Runtime can request background and corner-logo image reloads. |
| `persistence` | wired | Runtime can persist selected preference updates. |
| `media` | not migrated | Media playback effects are recorded, but production runtime has no media playback port. |
| `bgm` | not migrated | BGM playback effects are recorded, but production runtime has no BGM playback port. |
| `projection` | not migrated | Projection effects are recorded, but production runtime has no projection port. |
| `ppt` | recording only | PPT effects are not emitted for operator toggles and production runtime has no PPT port. |
| `automation` | not migrated | AppleScript execution is still ViewModel-owned. |
| `automationNotice` | recording only | Runtime records notice effects, while ViewModel state sync drives the UI. |
| `bgmTimer` | not migrated | BGM timer effects are recorded only. |
| `support` | not migrated | Support event persistence stays in runtime state and ViewModel sync, not a production port. |

## Restart Boundary

Media restart is deliberately split in this PR. The media restart effect is not
executed by runtime yet; ViewModel still executes media restart through
`programRestartFromBeginningHandler`, while the audio routing port is wired and
receives the reduced runtime audio state after restart intent.
