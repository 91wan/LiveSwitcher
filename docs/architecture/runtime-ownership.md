# Live Runtime Ownership

## Production configuration

Current authoritative runtime domains: Audio; Media playback; BGM playback and progress timer; Projection output; PPT EventTap lifecycle; Support event storage and ingress; Automation command execution; Presentation query lifecycle.

Production bridge mode is `.panicOwned`. Production bridge mode remains `.panicOwned`; production panic transition ownership is expressed by `.panicOwned`. `.fullRuntime` remains test-only. Tests must use explicit bridge mode: `LiveRuntimeEnvironment()` must not imply production-unsafe full runtime. Bridge mode is explicit and never inferred from ports. A custom `LiveRuntimeEffectRunner` must always be paired with an explicit `LiveRuntimeEnvironment`.

Ports describe executable capabilities. Bridge mode describes domain ownership. A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed. Operator actions for mirror-only domains must not mutate real runtime domain state.

Connected production ports: `media`, `bgm`, `bgmTimer`, `projection`, `ppt`, `automationNotice`, `support`, `automation`, `presentationQuery`, `panicDelay`. Production uses `.panicOwned` and wires Support through Runtime facade sync.

## Ownership matrix

| Domain | Owner | Notes |
| --- | --- | --- |
| Program queue | Runtime owner | Program queue storage/mutation is runtime-owned. Program Queue mutation logic is routed through `Runtime/ProgramQueueRuntimeReducer.swift`; Pure Program queue mechanics remain in `Runtime/ProgramQueueRuntimeMutations.swift`; Main `LiveRuntimeReducer.swift` routes Program Queue actions only. |
| Media playback | Runtime owner | Media callbacks require `.media` ownership. AVPlayer state enters Runtime only through guarded media callback actions. |
| BGM | Runtime owner | Runtime owns BGM fade-in and fade-out behavior; BGM playback and progress timer use Runtime state. |
| Audio routing | Runtime owner | Audio routing context is stored inside `AudioRuntimeState`; Effective audio output getters are pure Runtime state reads. |
| Panic | Runtime owner | Panic delayed BGM pause is represented by `panicBGMPauseDelayElapsed`; there is no separate `panicFadeCompleted` action. |
| PPT mode | Runtime owner | PPT EventTap lifecycle is runtime-owned; Runtime owns `state.ppt.isRequested`; `isPageInterceptEnabled` is a projection. |
| Projection | Runtime owner | Projection output is runtime-owned; Runtime owns projection start/stop decisions. |
| Automation notice | Runtime owner | Automation notice lifecycle is runtime-owned; Runtime owns `state.automation.notice` and `state.automation.suppressionUntilByAction`. |
| Support | Runtime owner | Support storage, production ingress, and facade projection use Runtime state; Support storage and production ingress are runtime-owned. |
| Automation command execution | Runtime owner | Automation command execution is runtime-owned only for fire-and-forget. |
| Presentation query lifecycle | Runtime owner | Presentation Query lifecycle mutation is routed through `PresentationQueryRuntimeReducer.swift`. |
| Preferences / persisted settings | ViewModel owner | Preference mutation logic lives in `Runtime/PreferencesRuntimeReducer.swift`; Main `LiveRuntimeReducer.swift` routes preference actions only; No `.preferences` Runtime domain or port exists. |
| Persistence | ViewModel owner | Hydration and save timing remain outside Runtime reducers. |

| Port | Status |
| --- | --- |
| `media` | wired |
| `bgm` | wired |
| `bgmTimer` | wired |
| `projection` | wired |
| `ppt` | wired |
| `automationNotice` | wired |
| `support` | wired |
| `automation` | wired |
| `presentationQuery` | wired |
| `panicDelay` | wired |

## Runtime-owned domains

No next domain may be migrated until the Audio, Media, BGM, Projection, Panic, PPT, automation notice, support, automation command, presentation query, program queue, program selection, and program activation gates are green. Projection start/stop output plus Panic transition orchestration plus PPT EventTap lifecycle plus automation notice lifecycle are Runtime-owned.

Audio and BGM: `facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state. Audio routing context must use Runtime-owned media, current program, Panic, and BGM state whenever those domains are owned. AudioRuntimeReducer and BGMRuntimeReducer own their extracted mutation helpers. Audio runtime mutation logic lives in `AudioRuntimeReducer.swift`. Manual BGM stop uses `LiveRuntimeEnvironment.liveAudioFadeDuration`; BGM fallback cleanup does not require the current track to be nil; Runtime may keep a current BGM item selected while stopped.

Media and snapshots: Media playback is runtime-owned. MediaRuntimeReducer owns media mutation; Media Runtime mutation logic lives in `MediaRuntimeReducer.swift`. Load/play/pause/restart/stop/seek effects execute through `MediaPlaybackPort`. Runtime callback actions must not mutate domains before ownership. When `.media` is owned, media snapshot state is preserved from Runtime. `ViewModel+RuntimeSnapshot.swift` is a boundary adapter, not a second source of truth. When `.programSelection` is owned, current program media-source status is derived from Runtime current program state. Current Program selection is mutated only by real Runtime selection and clear actions. Current Program facade projection is sync-only. Runtime state writes must use real selection/clear actions instead of compatibility mirror actions. There is no `facadeCurrentProgramChanged` compatibility action.

Projection: The concrete output window remains inside the ProjectionPort. Projection start failure is distinct from display loss. `makeRuntimeStateSnapshot()` preserves Runtime-owned `ProjectionRuntimeState` and must not overwrite Runtime-owned `ProjectionRuntimeState`. `projectionStartFailed` records start failure semantics. `projectionExternalDisplayLost` is only for broadcasting loss. Raw output-window show/hide side effects are internal ProjectionPort.

PPT: PPT key forwarding, WPS fallback branching, permission alert UI, and PPT support event generation remain ViewModel-owned. PPT EventTap lifecycle, key forwarding, WPS key forwarding, and automation permission modal alerts live in `ViewModel+PPTEventTap.swift`. Runtime-owned PPT callbacks must not write support storage directly.

Automation notice and command: Production uses `AutomationNoticePort` effects. Automation notice expiry tasks are ID-bound. Showing a replacement notice, dismissing the current notice, manually expiring it, clearing Runtime notice state, and stale expiry callbacks cannot clear a newer notice. `automationNoticeRequested` and `automationNoticeExpired` are internal lifecycle actions. `automationFailed` remains the meaningful system event. Automation command execution effect emission is routed through `AutomationCommandRuntimeReducer.swift`; Main `LiveRuntimeReducer.swift` routes `automationScriptRequested` only; `automationScriptRequested` does not dispatch audio-input sync. Automation failure / notice lifecycle remains in `AutomationNoticeRuntimeReducer`.

Presentation query and program activation: ViewModel owns query result normalization and consumption side effects. `PresentationQueryRuntimeState` retains consumed-ID mechanics and limit. Query callbacks are accepted only for the active request ID. Stale query callbacks must not mutate result/failure state. Presentation Query lifecycle mutation is routed through `PresentationQueryRuntimeReducer.swift`; Main `LiveRuntimeReducer.swift` routes Presentation Query actions only. Program activation/switching side effects stay outside Runtime state; Program Activation request/completion lifecycle mutation is routed through `ProgramActivationRuntimeReducer.swift`; Main `LiveRuntimeReducer.swift` routes Program Activation actions only. Activation plans are not stored in Runtime state. Stale completion must not clear newer active request.

## ViewModel-owned responsibilities

ViewModel still owns AppleScript source construction. Keynote/WPS result-returning AppleScript queries, `PresentationQueryService` remains ViewModel-owned, and result-returning automation queries and key-forwarding migration remain blocked. Future query migrations must introduce explicit command/query IDs and callback result actions. Future callback-capable Runtime ports must use `LiveRuntimeEffectExecutionContext`; Future callback-capable Runtime ports must use `LiveRuntimeEffectExecutionContext.dispatch`.

Presentation automation source construction lives in `ViewModel+PresentationAutomation.swift`. Automation failure support handling and the concrete automation notice facade live in `ViewModel+AutomationFailure.swift`. Projection output/window/support side effects live in `ViewModel+ProjectionOutput.swift`. The thin Support ingress facade `recordSupportEvent(...)` lives in `ViewModel+SupportFacade.swift`; `ViewModel+SupportFacade.swift` owns `recordSupportEvent(...)`; ViewModel.recordSupportEvent dispatch `.supportEventRecorded`.

Program queue facades live in `ViewModel+ProgramQueue.swift`. Media playback callback setup, playback-ended handling, and the HTML presentation facade live in `ViewModel+MediaPlayback.swift`. Wallpaper and corner-logo asset library facade lives in `ViewModel+Assets.swift`. Automation query/result flows remain ViewModel-owned. Support production ingress is runtime-owned. Support event generation call sites, and telemetry remain ViewModel-owned. Support event generation call sites and telemetry remain ViewModel-owned.

Projection output controller storage, external-display availability mutation; PPT EventTap raw handles, pending PPT toggle source, WPS application monitoring; BGM transition generation, active BGM timer generation, and last audio-routing transition storage are encapsulated behind narrow ViewModel accessors. Result-returning query migration must also wait for the Projection/PPT encapsulation gates.

## Boundary invariants

### Dispatch and facade sync

ViewModel callback wiring remains simple and does not check ownership. Dispatch uses `LiveRuntimeFacadeSyncPolicy` for projected state. Support ingress must rely on `LiveRuntimeFacadeSyncPolicy` to sync; `syncSupportFacadeFromRuntime()` requires `.support` ownership. Support Runtime returns the exact accepted event stored in `state.support.events` and emits `.recordSupportEvent` only for that accepted event. `.supportEventRecorded` is support ingress, not operator intent, and is suppressed from the operator-facing Runtime action log. Must not manually call Support facade sync after dispatch; must not write Support storage in `.automationNoticeOwned`, `.supportOwned`, `.automationCommandOwned`, `.presentationQueryOwned`, `.programQueueOwned`, `.programSelectionOwned`, `.programActivationOwned`, or `.panicOwned`.

### Snapshot direction

When `.projection` is owned, projection snapshot state is preserved from Runtime. Runtime-owned snapshots flow Runtime-to-facade. Legacy facade state may seed only domains that are not runtime-owned.

`makeRuntimeStateSnapshot()` must not overwrite Runtime-owned `ProjectionRuntimeState`.

### Async callback acceptance

Media callbacks require `.media` ownership. BGM callbacks require `.bgm` ownership. External display polling enters Runtime through projection callback actions. Query callbacks are accepted only for the active request ID.

### Persistence

Persistence load hydrates facades, then explicit Runtime snapshot/environment adapters establish owned state. It must not infer bridge mode or mutate owned runtime domains from stale facade state.

### Program activation

Program activation request/completion lifecycle is Runtime-owned. Program activation concrete switching side effects are still ViewModel-owned. Program activation records request/completion lifecycle only. It must not store activation plans in Runtime state, and stale completion must not clear newer active request. The activation effect executes only while Runtime's active request ID matches its request ID, verifies that Runtime accepted the requested selection before post-selection side effects run, stale activation effects must not run side effects, and rejected selection must not run post-selection side effects.

### BGM library mirror

BGM library edits remain ViewModel-side storage operations but must mirror Runtime BGM items immediately so Runtime-owned playback state does not resurrect removed items.

### Panic

Panic transition orchestration is runtime-owned. Panic transition uses Runtime-owned media/BGM state and `panicDelay`; the delayed BGM pause callback is generation-bound.

## Forbidden architecture changes

Runtime action surface should not include no-op lifecycle actions. BGM preparation is represented by the `.prepareBGM` effect and real playback callbacks. Main `LiveRuntimeReducer.swift` remains route-only.

Do not append support events directly, perform local redaction/coalescing/trimming, or write Support storage in `.automationNoticeOwned`, `.supportOwned`, `.automationCommandOwned`, `.presentationQueryOwned`, `.programQueueOwned`, `.programSelectionOwned`, `.programActivationOwned`, or `.panicOwned`.

Broader result-returning automation queries remain blocked from this boundary. Projection/PPT/Support facade extraction tests and media/assets extraction tests guard these boundaries. Runtime-owned facades must not own audio routing method bodies or concrete BGM player lifecycle method bodies, media callback/HTML presentation method bodies, or wallpaper/corner-logo library method bodies.

Bridge modes are cumulative migration stages: `.bgmOwned` means Audio + Media + BGM, not Audio + BGM; `.projectionOwned` means Audio + Media + BGM + Projection; `.pptOwned` means Audio + Media + BGM; `.automationNoticeOwned` means Audio + Media + BGM + Projection + PPT + Automation notice; `.supportOwned` means Audio + Media + BGM + Projection + PPT + Automation notice + Support.
