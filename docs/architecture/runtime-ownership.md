# Live Runtime Ownership

## Production configuration

Production bridge mode: `.panicOwned`.

Production bridge mode is `.panicOwned`.

Executable truth lives in code, in this order: `LiveRuntimeBridgeMode.ownedDomains`, production `SwitcherRuntimePortBundle` / `connectedPortKinds`, reducer behavior tests, then this document.

Production owned domains: `.audio`, `.media`, `.bgm`, `.projection`, `.panic`, `.ppt`, `.automationNotice`, `.support`, `.automationCommand`, `.presentationQuery`, `.programQueue`, `.programSelection`, `.programActivation`, `.imageAssets`, `.persistence`.

Production connected ports: `.media`, `.bgm`, `.bgmTimer`, `.panicDelay`, `.projection`, `.ppt`, `.automation`, `.automationNotice`, `.support`, `.presentationQuery`, `.programActivation`, `.audioRouting`, `.imageAssets`, `.persistence`.

`automationCommand` is an ownership domain. `automation` is an effect port for executable AppleScript capability. `.panicOwned` owns `.automationCommand`; it does not own an `.automation` domain.

Bridge modes are cumulative test/migration stages. The executable truth is `LiveRuntimeBridgeMode.ownedDomains`; this document must not restate every stage in prose.

## Ownership matrix

| Area | Authoritative state owner | Concrete adapter / remaining ViewModel responsibility |
| --- | --- | --- |
| Audio controls/routing | Runtime | audio device/player adapters |
| Media playback | Runtime | AVPlayer adapter |
| BGM playback/timer | Runtime | player/timer adapters |
| BGM library metadata | ViewModel | `facadeBGMLibraryChanged` mirror |
| Projection | Runtime | display/window adapter |
| Panic transition | Runtime | telemetry/support call sites in ViewModel |
| PPT EventTap lifecycle | Runtime | key forwarding and permission UI in ViewModel |
| Automation Notice | Runtime | facade projection |
| Support storage/ingress | Runtime | event generation and telemetry in ViewModel |
| Automation command execution | Runtime lifecycle/effect | script construction in ViewModel |
| Presentation Query lifecycle | Runtime | normalization/consumption side effects in ViewModel |
| Program Queue | Runtime | UI call sites in ViewModel |
| Current Program Selection | Runtime | facade projection |
| Program Activation lifecycle | Runtime | planner and concrete side effects in ViewModel |
| Preferences state mutation | Runtime under `.persistence` | UI facade / persistence store |
| Persistence effect execution | Runtime infrastructure | `SwitcherPersistenceStore` |
| Asset image loading | Runtime infrastructure | asset library editing in ViewModel |

## ViewModel-owned responsibilities

ViewModel still owns concrete UI adapters and human-facing side effects: output windows, raw device bridges, permission UI, script construction, query normalization/consumption, support event generation, telemetry, setup editing, and `SwitcherPersistenceStore` orchestration.

Media playback is runtime-owned. Load/play/pause/restart/stop/seek effects execute through `MediaPlaybackPort`.

Media Runtime mutation logic lives in `MediaRuntimeReducer.swift`; Audio runtime mutation logic lives in `AudioRuntimeReducer.swift`.

Keynote/WPS result-returning AppleScript queries remain ViewModel-owned. Future query migrations must introduce explicit command/query IDs and callback result actions before Runtime can own those lifecycles.

Preference state mutation is Runtime-owned under `.persistence` and routed through `PreferencesRuntimeReducer`. Persistence effects are emitted by Runtime and executed through `PersistencePort`. Concrete persistence storage and load orchestration remain ViewModel / `SwitcherPersistenceStore` responsibilities. Persistent hydration is a semantic `LiveRuntimeStore` operation.

## Boundary invariants

### Dispatch and facade projection

Runtime-owned domains project state back to the facade through sync policy. Facade projection must not become a second source of truth or write Runtime-owned state directly.

### Snapshot direction

Runtime-owned snapshot fields flow Runtime-to-facade. Facade state may seed only domains that are not owned by the active bridge mode.

### Async callback acceptance

Callback actions are accepted only by domains owned by the active bridge mode, and stale callbacks must not mutate newer Runtime state.

### Persistence

Persistent load must not infer bridge mode. Hydration may establish semantic Runtime state, while concrete save/load mechanics stay behind persistence adapters.

### Program activation

Program activation request/completion lifecycle is Runtime-owned. Program activation concrete switching side effects are still ViewModel-owned.

Runtime owns activation request/completion lifecycle. ViewModel owns the planner and concrete switching side effects, which run only after Runtime accepts the requested selection for the active request.

Program activation executes only while Runtime's active request ID matches its request ID. It verifies that Runtime accepted the requested selection before post-selection side effects run; stale activation effects must not run side effects, and rejected selection must not run post-selection side effects.

### BGM library mirror

BGM library metadata is ViewModel-owned setup data. Runtime receives the mirrored item list through `facadeBGMLibraryChanged` so playback state cannot resurrect removed items.

### Panic

Panic transition orchestration is runtime-owned. Panic transition state and delayed BGM pause are Runtime-owned. ViewModel may still generate telemetry/support events around operator-facing emergency workflows.

## Architecture freeze

Architecture tests should verify executable contracts and document structure, not long prose sentences or implementation file placement. New Runtime ownership, ports, bridge modes, or Live Mode controls require an explicit contract.
