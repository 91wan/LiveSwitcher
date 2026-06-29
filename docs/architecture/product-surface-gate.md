# Product Surface Change Gate

This gate applies before adding or changing any operator-visible product surface. It is especially strict for Live Mode because Live Mode is an active-show execution surface, not a configuration or management surface.

New Live Mode controls are default-denied. A new live control must prove that the control reduces operator accidents, replaces or merges an existing action, and preserves the current Live Mode simplicity boundary.

## Review Questions

Every product-surface proposal must answer these questions before implementation:

1. Is this live execution or setup configuration?
2. Does this enter Live Mode?
3. If it enters Live Mode, which existing action does it replace?
4. Does it increase accidental-trigger risk?
5. Does it require external display hardware acceptance?
6. Who owns the Runtime state?
7. Could support reports leak customer content?
8. Is there a chance to delete or merge an existing control?

## Phone LAN Remote Boundary

Phone LAN remote may invoke existing allowed Live Mode actions without adding new Mac Live Mode controls.

Phone remote setup belongs outside Live Mode. Pairing, QR display, remote enable/disable, local URL display, token lifecycle controls, and session diagnostics must stay in setup/support surfaces.

The phone remote is not a second switcher console. It may only expose a small approved subset of existing execution actions, must keep configuration/editing surfaces out of the phone UI, and must not bypass Runtime or ViewModel action boundaries.

Dangerous remote actions require strong confirmation. Any remote action that changes external display output, Panic, fade-to-black, playback, or BGM behavior must enter the hardware/manual acceptance matrix in its implementation PR.

## Allowed Live Mode Actions

The allowed Live Mode action list must stay in sync with `LiveModeSimplicityPolicy.allowedActions`.

| Token | Documentation label |
|---|---|
| `switchSource` | Switch source |
| `takeNext` | Take next |
| `toggleCurrentMediaPlayback` | Toggle main media playback |
| `returnCurrentMediaToStart` | Return current media to start |
| `toggleProjection` | Toggle projection |
| `togglePanic` | Toggle panic |
| `toggleFadeToBlack` | Toggle fade-to-black |
| `toggleSpeakerMode` | Toggle speaker mode |
| `togglePPTMode` | Toggle PPT mode |
| `bgmPlayPause` | Play or pause existing BGM |
| `bgmPrevious` | Select previous BGM |
| `bgmNext` | Select next BGM |
| `selectExistingBGM` | Select existing BGM |
| `triggerExistingOverlayPreset` | Trigger existing overlay presets |
| `selectExistingStandbyWallpaper` | Select existing standby wallpapers |

## Forbidden Live Configuration Surfaces

These configuration surfaces must not enter Live Mode. The forbidden list must stay in sync with `LiveModeSimplicityPolicy.forbiddenConfigurationSurfaces`.

| Token | Documentation label |
|---|---|
| `importProgramSource` | Importing or adding program sources |
| `editProgramQueue` | Editing the program queue structure |
| `editBGMLibrary` | Editing BGM library metadata |
| `editOverlayPreset` | Editing overlay preset definitions |
| `editAutomationSettings` | Editing automation settings |
| `editAgendaReminder` | Editing agenda reminder or auto-next preferences |
| `editReleaseBuildDebugSettings` | Editing release, build, debug, or developer settings |

## Approval Bar

A Live Mode change is not approved unless the proposal can show all of the following:

- It keeps setup configuration out of Live Mode.
- It identifies the existing action it replaces, merges, or deletes.
- It can prove that the control reduces operator accidents compared with the existing surface.
- It includes visible-behavior tests for the operator-facing result.
- It requires external display hardware acceptance when the audience output, projection state, panic state, fade-to-black state, wallpaper output, or any external-screen visible result changes.
- It names the Runtime owner and does not let View code directly mutate Runtime-owned state.
- It confirms support reports do not leak customer content such as names, media titles, imported file paths, event text, or generated diagnostics that include operator data.
- It includes an update LiveModeSimplicityPolicy step whenever a Live Mode action is added, removed, or renamed.

Runtime ownership, reducer extraction, facade hardening, or test cleanup work must not expand the Live Mode product surface unless a future contract explicitly changes this gate.
