# Live Runtime Ownership

This document is the current ownership map for the LiveSwitcher runtime facade.

Current authoritative runtime domains:
- Audio
- Media playback
- BGM playback and progress timer
- Projection output
- Panic transition orchestration
- PPT EventTap lifecycle
- Automation notice lifecycle
- Support event storage and ingress
- Automation command execution
- Image asset side-effect bridge
- Persistence side-effect bridge
- Presentation query lifecycle
- Program queue storage/mutation
- Current program selection state/projection

Program activation/switching side effects, source validation,
invalid-deck alerts, WPS fallback branching, PPT/WPS key forwarding,
Automation query/result flows, BGM library metadata, and asset-library mutation
are not runtime-owned.
Program queue storage/mutation is runtime-owned and projected to
`SwitcherViewModel.programItems` when `.programQueueOwned`. The facade property
has a private setter; runtime projections flow through
`applyProgramQueueProjectionFromRuntime(_:)`, and pure queue mechanics live in
`Runtime/ProgramQueueRuntimeMutations.swift`. Current program selection is
runtime-owned in `.programSelectionOwned` and projected through
`applyCurrentProgramProjectionFromRuntime(_:switchedAt:)`; pure selection
mechanics live in `Runtime/ProgramSelectionRuntimeReducer.swift`. Queued and
detached selection use distinct payload-safe action names:
`operatorSelectedProgram` and `operatorSelectedDetachedProgram`.
`facadeCurrentProgramChanged` is compatibility-only and is not used by
production selection paths. Program activation request/completion lifecycle is
Runtime-owned in `.programActivationOwned`; Runtime records the active request
ID, emits `.executeProgramActivation(id:plan:)`, and accepts matching completion
callbacks. `ProgramActivationPort` executes only while Runtime's active request
ID matches its request ID, and it completes only the still-active request. Stale
activation effects must not run side effects or clear newer activation
requests. Program activation concrete switching side effects are still
ViewModel-owned through `ProgramActivationSideEffectHandlers`. Program
activation planning lives in pure model types, `ProgramActivationPlan` and
`ProgramActivationPlanner`, and the planner call site remains in
`ViewModel+ProgramActivation.swift`. `ProgramActivationPlan` explicitly models
pre-selection and post-selection phases: invalid decks are pre-selection aborts,
deck stop is a pre-selection side effect, Runtime current program selection
runs before post-selection effects, and `ProgramActivationPort` verifies that
Runtime accepted the requested selection before post-selection side effects run.
Rejected selection must not run post-selection side effects. Source validation
and source availability classification remain ViewModel-owned; classification
lives in the pure `ProgramSourceAvailabilityPolicy`, while missing-source
support/notice generation remains ViewModel-owned.
Panic transition policy is pure and lives in `PanicTransitionPolicy`; it owns
snapshot, immediate media pause, delayed BGM pause, and media/BGM resume
decisions. Panic transition orchestration is runtime-owned in `.panicOwned`:
`PanicRuntimeReducer` uses `PanicTransitionPolicy` for snapshot, pause,
delayed pause, and resume decisions, and production wires `PanicDelayPort` for
the concrete delayed BGM pause task. BGM pause after Panic activation preserves
`liveAudioFadeDuration`. The Panic reducer must not write support; Panic support
events and telemetry remain ViewModel-owned. In `.panicOwned`,
`runtime.state.panic` is the source of truth: `togglePanicMode()` derives its
target from Runtime state, `isPanicMode` and `panicPlaybackSnapshot` are
Runtime-backed facade projections, and Runtime-backed audio snapshots use
Runtime Panic state rather than stale facade state. `PanicDelayPort` clears its
ViewModel-owned task and generation bookkeeping after a matching delayed
callback fires or cancelation matches. Fade-to-black remains visual-only and
ViewModel-owned.
Panic snapshot stopped-state mutation is Runtime-owned when `.panic` is owned.
`PanicRuntimeReducer` marks snapshot media stopped only when the matching current
media reaches end or is operator-stopped during Panic. It marks snapshot BGM
stopped only when the matching current BGM reaches end, fails, is stopped, or a
new BGM is selected during Panic. Normal Panic media/BGM pause does not clear
snapshot playback flags because those captured items remain eligible to resume
on Panic OFF. ViewModel Panic snapshot mutation helpers are legacy fallback only
before `.panicOwned`, and Panic OFF resumes only from Runtime snapshot truth.
Activation execution, invalid-deck alerts, and activation side-effect
orchestration live in `ViewModel+ProgramActivationRuntimeBridge.swift` behind
`ProgramActivationPort`. Current-program media
transport controls live in `ViewModel+ProgramMediaTransport.swift`.
Activation ordering is guarded by real ViewModel behavior tests, not source-only
assertions.
`ViewModel+ProgramQueue.swift` is the queue mutation facade only.
Audio routing facade code that bridges Runtime-owned audio decisions to concrete
players, faders, and system volume observation lives in
`ViewModel+AudioRouting.swift`.
BGM runtime playback facade code that bridges Runtime-owned BGM state to
`AVAudioPlayer`/`AVPlayer`, fallback playback, fade tasks, progress timers, and
realtime metering lives in `ViewModel+BGMRuntimePlayback.swift`.
BGM library editing and operator selection facade methods remain ViewModel-owned
and live in `ViewModel+BGMControls.swift`.
BGM Runtime mutation logic lives in `Runtime/BGMRuntimeReducer.swift`; the main
`LiveRuntimeReducer.swift` should route BGM actions and keep ownership guards,
not own BGM selection, stop, seek, progress, adjacent-selection, or reached-end
mutation bodies. `BGMRuntimeReducer` may call Runtime audio helper methods until
a dedicated `AudioRuntimeReducer` extraction is planned as future work.
Media playback callback setup, playback-ended handling, and the HTML
presentation facade live in `ViewModel+MediaPlayback.swift`. Panic is a hard
Runtime media playback gate: operator media toggle must not start playback,
media restart is a cue-to-start operation that emits `.seekMediaToStart`
instead of `.restartMedia`, and selecting a media program during Panic loads the
program without playing it. `operatorResumedMediaAfterPanic` is ignored while
Panic is still active. Restart/seek/toggle pause during Panic does not clear the
Panic snapshot media playback flag; if the snapshot captured media as playing,
Panic OFF may still resume that media from the cued position.
The wallpaper and corner-logo asset library facade lives in
`ViewModel+Assets.swift`.
Program activation side effects are grouped under
`ProgramActivationSideEffectHandlers` and configured in
`ViewModel+ProgramActivationSideEffectWiring.swift`.
`SwitcherViewModelActionHandlers` has been removed. Media seek/restart no
longer has action-handler bypasses; media transport goes through Runtime media
actions and `MediaPlaybackPort` effects. Test-only seams are grouped under
`SwitcherViewModelTestHooks`. Main `ViewModel.swift` may retain private storage
and narrow bridge accessors, but it must not accumulate loose action handler or
test-hook fields. Moving code into extensions must not widen private ViewModel
state just to make files look smaller.
The main `ViewModel.swift` must not own audio routing method bodies or concrete
BGM player lifecycle method bodies, media callback/HTML presentation method
bodies, or wallpaper/corner-logo library method bodies. Result-returning
broader automation query migration remains blocked unless a later contract
explicitly approves it.
Presentation automation source construction, Keynote/WPS result-returning
AppleScript queries, Keynote/WPS/PPT scans, and WPS fallback branching remain
ViewModel-owned and live in `ViewModel+PresentationAutomation.swift`.
Presentation query implementation is isolated behind `PresentationQueryService`,
and query-result normalization/dedupe is isolated behind
`PresentationQueryResultBuilder`; these are extraction boundaries only.
`PresentationQueryService` owns only injected AppleScript runner and open-file
provider dependencies and has no `KeynoteController` dependency.
`PresentationQueryResult` is the stable query result payload passed from the
Runtime presentation-query callback into ViewModel-owned normalization. Title cleanup is isolated in
`PresentationWindowTitlePolicy`; `KeynoteController` delegates to that pure
policy for compatibility. The narrow presentation query lifecycle uses explicit
query IDs and callback result actions before ViewModel consumes the result.
`LiveRuntimeEffectExecutionContext` carries `currentState` and `dispatch` for
effect execution. Result-returning Runtime ports dispatch callback actions
through that execution context, not through direct `SwitcherViewModel` dispatch
closures.
Automation failure support handling and the concrete automation notice facade
live in `ViewModel+AutomationFailure.swift`.
Projection output/window/support side effects live in
`ViewModel+ProjectionOutput.swift`. PPT EventTap lifecycle, key forwarding,
WPS key forwarding, and automation permission modal alerts live in
`ViewModel+PPTEventTap.swift`. The thin Support ingress facade
`recordSupportEvent(...)` lives in `ViewModel+SupportFacade.swift`.
Support event generation call sites, persistence state application, and
telemetry remain ViewModel-owned. The main `ViewModel.swift` must not own
Projection output method bodies or PPT EventTap/key-forwarding method bodies.
For automation ownership gates, support event generation call sites, and
telemetry remain ViewModel-owned; persistence state application is also
ViewModel-owned.
Their runtime state is either a ViewModel-owned snapshot or an explicit callback
from an already-executed facade path. Operator actions for unowned domains must
not mutate real domain state or infer playback/output state that the ViewModel
has not synchronized into the runtime snapshot.

## Production Bridge Mode

Production bridge mode is `.panicOwned`.
`.fullRuntime` remains test-only; production panic transition ownership is
expressed by `.panicOwned`.
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
| `automationNoticeOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle |
| `supportOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress |
| `automationCommandOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution |
| `presentationQueryOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution, Presentation query lifecycle |
| `programQueueOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution, Presentation query lifecycle, Program queue storage/mutation |
| `programSelectionOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution, Presentation query lifecycle, Program queue storage/mutation, Current program selection |
| `programActivationOwned` | Audio, Media playback, BGM, Projection, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution, Presentation query lifecycle, Program queue storage/mutation, Current program selection, Program activation request/completion lifecycle |
| `panicOwned` | Audio, Media playback, BGM, Projection, Panic transition orchestration, PPT EventTap lifecycle, Automation notice lifecycle, Support event storage and ingress, Automation command execution, Presentation query lifecycle, Program queue storage/mutation, Current program selection, Program activation request/completion lifecycle |
| `fullRuntime` | all runtime domains, test-only until deliberately approved |

`.bgmOwned` means Audio + Media + BGM, not Audio + BGM. `.projectionOwned`
means Audio + Media + BGM + Projection. `.pptOwned` means Audio + Media + BGM
+ Projection + PPT EventTap lifecycle. `.automationNoticeOwned` means Audio +
Media + BGM + Projection + PPT EventTap lifecycle + Automation notice
lifecycle. `.supportOwned` means Audio + Media + BGM + Projection + PPT
EventTap lifecycle + Automation notice lifecycle + Support event storage and
ingress. `.automationCommandOwned` means Audio + Media + BGM + Projection +
PPT EventTap lifecycle + Automation notice lifecycle + Support event storage
and ingress + Automation command execution. `.presentationQueryOwned` adds the
narrow presentation query request/result/failure lifecycle. `.programQueueOwned`
adds Program queue storage/mutation. `.programSelectionOwned` adds current
program selection state and facade projection without migrating Program
activation side effects or broader automation ownership. `.programActivationOwned`
adds Program activation request/completion lifecycle and effect dispatch while
keeping source validation, plan construction, and concrete activation side
effects ViewModel-owned. `.panicOwned` adds Panic transition orchestration while
keeping fade-to-black, support event generation, and telemetry ViewModel-owned.
In `.panicOwned`, `isPanicMode` and `panicPlaybackSnapshot` are private-set
Runtime-backed projections; they are not independent source-of-truth fields.

In this mode the runtime reducer owns `state.audio`, `state.media`,
`state.bgm`, `state.projection`, PPT requested/active/failure state, and
`state.automation.notice` plus `state.automation.suppressionUntilByAction`, and
`state.support`, fire-and-forget automation command execution,
`state.presentationQuery`, Program queue storage/mutation in
`state.program.items`, and current program selection fields
`state.program.currentID`, `state.program.currentDetachedItem`, and
`state.program.currentSwitchedAt`, `state.programActivation`, and
`state.panic`. It may
execute the wired ports needed for current production
behavior. Connected production ports: `media`, `bgm`, `bgmTimer`, `projection`,
`ppt`, `automationNotice`, `support`, `automation`, `presentationQuery`,
`programActivation`, `panicDelay`, `audioRouting`, `imageAssets`, and `persistence`. The
audio routing, projection, PPT EventTap, automation notice, Support, automation
command, presentation query, Program activation, and Panic delay ports are
wired. Audio routing context is stored inside `AudioRuntimeState`, so Panic
routing inputs flow from runtime-owned state.

The reducer may record operator intent in the action log, but operator actions
for mirror-only domains must not change Panic, automation query/result flows, or
unowned domain state.
Mirror state changes for those domains must come from facade synchronization or
explicit callback actions such as media playback callbacks. PPT EventTap
lifecycle changes and automation notice lifecycle changes flow through Runtime
operator actions and callback actions. Support events enter Runtime through the
explicit `.supportEventRecorded` facade action.

Support storage, production ingress, and facade projection use Runtime state.
Runtime also owns accepted-event selection before notification port effects.
`ViewModel.recordSupportEvent` is now a thin Runtime facade that dispatches
`.supportEventRecorded` and syncs `supportEvents` from `runtime.state.support`.
Reducer-generated support events remain full-runtime/test-only; production
support writes use `.supportEventRecorded`.
`facadeAudioInputsChanged` updates audio routing context, not BGM/Panic mirror state.
Effective audio output getters are pure Runtime state reads.

A domain is not runtime-owned until its ports are wired and its legacy ViewModel mutation has been removed.
Operator actions for mirror-only domains must not mutate real runtime domain state.
No next domain may be migrated until the Audio, Media, BGM, Projection, Panic, PPT,
Automation notice, Support, and Automation command ownership tests pass and
production effective audio output plus media/BGM playback output plus
projection start/stop output plus Panic transition orchestration plus PPT EventTap lifecycle plus automation notice
lifecycle plus Support ingress plus automation command execution remain
runtime-owned. Result-returning automation queries and key-forwarding migration
remain blocked until a dedicated ownership PR is approved. Query migration is
also blocked until the persistence extraction tests pass, so restored state,
repaired wallpaper/logo paths, and missing-file support events have one
explicit owner.

## Domain Ownership

| Domain | Current owner | Runtime role | Migration state | Notes |
| --- | --- | --- | --- | --- |
| Program queue | Runtime owner | Authoritative queue items and queue mutation actions | authoritative | Runtime owns `state.program.items`, add/remove/move/schedule/agenda mutations, and `facadeLoadedProgramQueue` persistence hydration. Queue mechanics are pure `ProgramRuntimeState` mutations in `Runtime/ProgramQueueRuntimeMutations.swift`; the action log reports `queueCount` without item titles or paths. `programItems` is a private-set Runtime-backed facade projection when `.programQueueOwned` or later. `ViewModel+ProgramQueue.swift` is the queue mutation facade only. ViewModel still owns Program activation invalid-deck alerts, support event generation decisions, and live activation side effects through `ViewModel+ProgramActivationRuntimeBridge.swift`; pure source availability classification lives in `ProgramSourceAvailabilityPolicy`, and current-program media transport controls live in `ViewModel+ProgramMediaTransport.swift`. |
| Current program selection | Runtime owner | Authoritative selected queued/detached item, switched-at timestamp, and facade projection | authoritative | Runtime owns `state.program.currentID`, `state.program.currentDetachedItem`, `state.program.currentSwitchedAt`, selected queued/detached program actions, clearing current selection when the current queue item is removed, and `currentProgramItem` / `currentProgramSwitchedAt` facade projection in `.programSelectionOwned`. Selection mechanics live in `Runtime/ProgramSelectionRuntimeReducer.swift`: `operatorSelectedProgram` means queued item selection, `operatorSelectedDetachedProgram` means detached item selection, and those redacted action names remain distinct while omitting titles and paths. `clearCurrentProgramSelection(reason:)` lives in `ViewModel+ProgramSelection.swift`; `ViewModel+RuntimeFacadeSync.swift` is Runtime-to-facade sync-only. Runtime reducer audio helpers are internal for Runtime domain reducers only and must not be called from ViewModel. `facadeCurrentProgramChanged` is compatibility-only, is suppressed from the action log, and must not be used by production selection paths. ViewModel still owns invalid-deck alerts, source availability checks, Keynote/WPS/HTML/media activation side effects, media transport controls, and support event generation decisions. Activation execution now runs explicit `ProgramActivationPlan` phases through `ProgramActivationPort`: pre-selection side effects first, Runtime selection second, current-program facade projection third, and post-selection effects last. |
| Program activation | Runtime lifecycle owner, ViewModel side-effect owner | Active request ID, completion lifecycle, and activation effect dispatch | lifecycle authoritative | Runtime owns `state.programActivation`, `operatorRequestedProgramActivation(id:plan:)`, `programActivationCompleted(id:)`, and `.executeProgramActivation(id:plan:)`. It does not store full plans in state and redacts recorded activation effects. `ProgramActivationPort` calls back into `ViewModel+ProgramActivationRuntimeBridge.swift`; it runs only for the active request, completes only that active request, and verifies Runtime accepted selection before post-selection effects run. Stale activation effects must not run side effects, and rejected selection must not run post-selection side effects. ViewModel-owned side effects execute through `ProgramActivationSideEffectHandlers`; source validation, source availability checks, invalid-deck validation, and `ProgramActivationPlanner` remain outside Runtime reducers. |
| Media playback | Runtime owner | Authoritative loaded URL, play/pause, restart, stop, seek, ended state, generation, and media effects | authoritative | Runtime emits `MediaPlaybackPort` effects; ViewModel bridges those effects to `AVPlayerCoordinator`. |
| BGM | Runtime owner | Authoritative current track, playback state, seek, loop-mode player side effects, progress, duration, generation, and timer effects | authoritative | Runtime emits `BGMPlaybackPort` and `BGMTimerPort` effects; ViewModel bridges those effects to `AVAudioPlayer`/`AVPlayer` and the progress timer. Runtime BGM playback effects remain BGM-domain effects; persisted play-mode preference writes use the Persistence domain. BGM Runtime mutation logic lives in `Runtime/BGMRuntimeReducer.swift`; `LiveRuntimeReducer.swift` routes BGM actions only. Panic snapshot mutation for BGM terminal/changing paths remains Runtime-owned through `PanicRuntimeReducer`. BGM library editing and metadata remain ViewModel-owned. |
| Audio routing | Runtime owner | Authoritative audio state and routing decisions | authoritative | Audio faders, mutes, strategy, speaker mode, takeover, routing context, and effective output are runtime-owned. |
| Image assets | Runtime bridge infrastructure | Wallpaper and corner-logo loading side effects | hardened bridge domain | Runtime-owned bridge modes except `.recordingOnly` own `.imageAssets`, so repaired or selected image URLs can reach `ImageAssetPort` without being mislabeled as Audio. Image library mutation, file repair decisions, and setup UI remain ViewModel/Persistence-owned. |
| Panic | Runtime owner, ViewModel support/telemetry owner | Authoritative active state, transition snapshot, snapshot stopped-state mutation, media/BGM pause/resume actions, delayed BGM pause scheduling, and facade projection | authoritative | Panic transition orchestration is runtime-owned in `.panicOwned`; media and BGM pause/resume go through Runtime actions. Pure transition decisions live in `PanicTransitionPolicy`, and Runtime reducer orchestration lives in `PanicRuntimeReducer`. Production wires `PanicDelayPort`; the concrete delayed pause task lives in `ViewModel+PanicDelayRuntimeWiring.swift` and dispatches elapsed callbacks through `LiveRuntimeEffectExecutionContext`. `togglePanicMode()` uses `runtime.state.panic.isActive` as source of truth when `.panic` is owned. `isPanicMode` and `panicPlaybackSnapshot` are Runtime-backed facade projections, and Runtime-backed audio snapshots use Runtime Panic state rather than stale facade state. Runtime marks matching snapshot media stopped for reached-end/operator-stop during Panic and matching snapshot BGM stopped for end/fail/stop/new-selection during Panic; normal Panic pause keeps resume eligibility. ViewModel snapshot mutation helpers are legacy fallback only before `.panicOwned`. Panic OFF resumes only from Runtime snapshot truth. `PanicDelayPort` clears task bookkeeping after matching fire/cancel paths. Fade-to-black remains visual-only and ViewModel-owned. The Panic reducer must not write support. |
| PPT mode | Runtime owner | Authoritative requested/active/failure state and EventTap lifecycle effects | authoritative | Runtime owns PPT mode request, active callback state, failure rollback, and `PPTEventTapPort` start/stop effects. ViewModel owns concrete CGEventTap fields, key forwarding, WPS automation implementation, permission alert UI, support event generation call sites, telemetry, and the `isPageInterceptEnabled` facade projection. |
| Projection | Runtime owner | Authoritative broadcast state, external-display availability, safety notice, display-loss timestamp, and start/stop effects | authoritative | Runtime owns projection start/stop decisions and emits canonical `ProjectionPort` effects. ViewModel owns the concrete `OutputWindowController`, target screen lookup, output view mounting, UI facade fields, support event generation call sites, and telemetry. |
| Automation notice | Runtime owner | Authoritative current notice, suppression window, show effect, expiry effect, dismiss, and expiry matching | authoritative | Runtime owns `state.automation.notice`, `state.automation.suppressionUntilByAction`, notice creation/throttling/expiry/dismissal, and `.showAutomationNotice` / `.expireAutomationNotice` effects through `AutomationNoticePort`. ViewModel owns the concrete `automationRuntimeNotice` facade field and syncs it from Runtime. |
| Support | Runtime owner | Authoritative support event list, redaction, coalescing, priority retention, event limit, accepted ingress action, facade projection sync, and notification port effect | authoritative | Runtime owns `state.support` and `.supportEventRecorded`. `SupportEventPort` receives only the accepted Runtime event after redaction, coalescing, and priority retention. It is notification-only; it syncs the ViewModel facade from Runtime and must not append duplicate events, redo redaction/coalescing, write UserDefaults, run telemetry, or execute automation. |
| Automation command execution | Runtime owner | Fire-and-forget AppleScript command request action and `runAppleScript` effect | authoritative | Runtime owns `.automationScriptRequested` and emits `.runAppleScript` only in `.automationCommandOwned`, `.presentationQueryOwned`, `.programQueueOwned`, `.programSelectionOwned`, or `.fullRuntime`. The `automation` port means fire-and-forget command execution only. ViewModel owns AppleScript source construction, concrete `AppleScriptRunner.run`, failure-to-support generation, and failure notice dispatch through `ViewModel+PresentationAutomation.swift` and `ViewModel+AutomationFailure.swift`. WPS fallback branching, PPT/WPS key forwarding, permission modal alerts, telemetry, and Support event generation decisions remain ViewModel-owned. |
| Presentation query lifecycle | Runtime owner | Operator query request, active query ID, callback result/failure state, and `scanPresentationQuery` effect | authoritative lifecycle, ViewModel-owned consumption | Runtime owns `.operatorRequestedPresentationQuery`, `.presentationQueryCompleted`, `.presentationQueryFailed`, `.presentationQueryResultConsumed`, `state.presentationQuery`, and `PresentationQueryPort`. `PresentationQueryPort` executes the existing `PresentationQueryService` through ViewModel wiring and dispatches callback actions through `LiveRuntimeEffectExecutionContext`. ViewModel owns result consumption: building program queue items, adding them, support event generation, and automation failure notice dispatch. |
| Persistence | `SwitcherPersistenceStore` + `ViewModel+Persistence.swift` facade | Wired preference persistence effects | hardened bridge domain and store | `SwitcherPersistenceStore` owns UserDefaults keys plus encode/decode and returns loaded state, missing-file support events, and explicit repair operations. `SwitcherViewModel.saveData()` / `loadData()` live in `ViewModel+Persistence.swift`: ViewModel snapshots state, applies loaded state idempotently, applies returned repairs explicitly, and records returned support events through Runtime support ingress. Runtime may persist selected preferences through the existing `PersistencePort` and `.persistence` domain, but general save/load mechanics are not runtime-owned. |

## Persistence Boundary

Persistence plumbing lives in `SwitcherPersistenceStore`. UserDefaults key names
are centralized in `SwitcherPersistenceKeys`; `ViewModel.swift` must not define
its own persistence key enum or write literal persistence keys directly.

`SwitcherPersistenceStore` owns encoding and decoding for program queue paths,
titles, subtitles, schedule fields, BGM library metadata, standby wallpapers,
active wallpaper validation, corner logo validation, audio/operator
preferences, and overlay preset JSON. `SwitcherPersistenceStore.load()` is
read-only: it may read UserDefaults, validate files, return state, return
support events, and return repairs, but it must not write UserDefaults.
Persistence repair writes are explicit via `applyRepairs(...)`.

`ViewModel+Persistence.swift` owns the persistence facade. `ViewModel.swift`
must not contain save/load plumbing. `SwitcherViewModel.saveData()` snapshots
current facade state and delegates to the store. `SwitcherViewModel.loadData()`
delegates to the store, applies returned persistent state idempotently, applies
returned repairs explicitly, and records each returned support event through
`recordSupportEvent(...)`; support ingress and facade projection therefore stay
Runtime-backed. Persistence hardening must not change Runtime bridge mode,
production connected ports, UI, UserDefaults key names, defaults, or query
ownership.

Runtime infrastructure domain hardening separates port connectivity from domain
ownership. Production still wires the same connected ports:
`media`, `bgm`, `bgmTimer`, `projection`, `ppt`, `automationNotice`,
`support`, `automation`, `presentationQuery`, `programActivation`,
`audioRouting`, `imageAssets`, and `persistence`.
The new `.imageAssets` and `.persistence` domains describe effect ownership,
not new production ports. `.recordingOnly` owns neither infrastructure domain;
every production owning mode from `.audioOwned` through `.fullRuntime` owns
both infrastructure domains. `PersistencePort` must implement each concrete
preference save method explicitly; there is no protocol-extension fallback from
specific preference saves to the generic `save()`.

`loadData()` is idempotent for restored program and BGM collections: applying a
persistent state replaces those collections rather than appending duplicate
items.

Result-returning automation query migration must not start unless the
persistence hardening tests, the program/presentation/automation-failure
extraction tests, the Projection/PPT/Support facade extraction tests, and the
existing Runtime ownership gates pass.

## Automation Command Boundary

Automation command execution is fire-and-forget only. Runtime action logging and
recorded effects must not retain raw AppleScript source, file paths, window
names, or query payloads. Recorded `.runAppleScript` effects keep only the
action name and store the script as `<redacted>`; the concrete automation port
still receives the original script only at the execution boundary.

Automation command failures are converted to sanitized category messages before
they enter Runtime failure actions. Runtime `.automationFailed` actions receive
only categories such as `compilationFailed`, `executionFailed`,
`permissionDenied`, or `applicationNotFound`. Support `appleScriptFailed`
details may include category plus redacted diagnostic text, but they must not
retain raw AppleScript source, file paths, or filenames.

Broader result-returning automation queries remain blocked from this boundary.
Future query migrations must introduce explicit command/query IDs and callback
result actions before Runtime can correlate asynchronous query results or query
failures. Future callback-capable Runtime ports must use
`LiveRuntimeEffectExecutionContext.dispatch`; effect callbacks must not bypass
Runtime by directly calling ViewModel dispatch closures. Until that dedicated
PR, WPS fallback branching and PPT/WPS key forwarding stay ViewModel-owned, and
`PresentationQueryService` remains ViewModel-owned.

## Bridge Slimming Rules

Runtime ownership is now broad enough that bridge infrastructure must stay out
of `ViewModel.swift`. The ViewModel remains a facade plus concrete platform
bridge; it should not become a dumping ground for generic adapter classes or
domain sync policy switches.

Runtime dispatch and callback bridge methods live in
`ViewModel+RuntimeFacade.swift`. Facade-to-runtime snapshot construction and
owned-domain preservation live in `ViewModel+RuntimeSnapshot.swift`.
Runtime-to-facade projection helpers live in
`ViewModel+RuntimeFacadeSync.swift`. Concrete ViewModel Runtime port wiring
lives in `ViewModel+RuntimeWiring.swift`. Generic closure-based Runtime port
adapters live in `LiveRuntimeClosurePorts.swift`.
Audio routing bridge methods live in `ViewModel+AudioRouting.swift`. BGM
runtime playback bridge methods live in `ViewModel+BGMRuntimePlayback.swift`.
BGM library editing and operator selection facade methods live in
`ViewModel+BGMControls.swift`. Media callback and HTML presentation facade
methods live in `ViewModel+MediaPlayback.swift`. Wallpaper and corner-logo asset
library facade methods live in `ViewModel+Assets.swift`.
Program queue methods live in `ViewModel+ProgramQueue.swift`. Presentation
automation source construction, result-returning scans, and WPS fallback
branching live in `ViewModel+PresentationAutomation.swift`. Automation failure
support handling and notice facade methods live in
`ViewModel+AutomationFailure.swift`. Projection output/window/support side
effects live in `ViewModel+ProjectionOutput.swift`. PPT EventTap lifecycle,
key forwarding, WPS key forwarding, and automation permission modal alerts live
in `ViewModel+PPTEventTap.swift`. PPT mode intent methods live in
`ViewModel+PPTMode.swift`. Default production Program activation side-effect
wiring lives in `ViewModel+ProgramActivationSideEffectWiring.swift`; Program
activation side effects remain ViewModel-owned behind `ProgramActivationPort`.
The Support ingress facade lives in
`ViewModel+SupportFacade.swift`.

`ViewModel.swift` must not own Runtime bridge mechanics. It may keep
ViewModel-owned orchestration for domains that are not part of the current
Runtime migration contract, but generic Runtime dispatch, snapshot, sync, port
wiring, and closure adapter mechanics belong in the narrow files above.
Moving bridge mechanics out of the core file must not expose private ViewModel
storage as broad module-wide mutable state. Cross-file Runtime extensions must
use narrow accessors and mutators for callback identity, support projection,
PPT EventTap snapshot state, persistence writes, and audio configuration.
Projection output controller storage, external-display availability mutation,
PPT EventTap raw handles, pending PPT toggle source, WPS application monitoring,
BGM transition generation, active BGM timer generation, and last audio-routing
transition storage are encapsulated behind narrow ViewModel accessors. Runtime
facade files may call those accessors, but must not treat the raw storage as
module-wide mutable state.
Projection read facades may remain in `ViewModel.swift` when moving them would
require widening `isExternalDisplayAvailable` or related private storage.
`supportEvents` is a Runtime-backed facade projection and is not broadly
mutable; Runtime sync updates it through the dedicated projection method.
Core model types such as `ProgramItem`, `BGMItem`, and `BGMPlayMode` live in
`Models/`, not in `ViewModel.swift`.

Runtime effect infrastructure is split by responsibility. `LiveRuntimeEffect.swift`
owns only the `LiveRuntimeEffect` enum; it must not contain port protocols,
effect-domain policy, redaction policy, port kind declarations, or the effect
runner. `LiveRuntimeEffect+Policy.swift` owns effect redaction and
`requiredBridgeDomain`. `LiveRuntimeEffectPortKind.swift` owns the port-kind
enum. `LiveRuntimePorts.swift` owns Runtime port protocols and must not add
default no-op/fallback implementations. `LiveRuntimeEffectRunner.swift` owns
side-effect execution, connected-port reporting, recorded-effect redaction, and
generation guards. Generic closure-based Runtime port adapters live in
`LiveRuntimeClosurePorts.swift`; production Runtime port bundle construction
lives in `SwitcherRuntimePortBundle.swift`. New Runtime ports must preserve
this split and must not be added inline in `ViewModel.swift`.
Concrete `SwitcherViewModel` Runtime port handler wiring lives in
`ViewModel+RuntimeWiring.swift`. `SwitcherViewModel.init` must not contain raw
Runtime port handler assignments. Future Runtime domain migrations must add
concrete ViewModel handler wiring through `configureRuntimePortHandlers(...)`,
not directly in the initializer. Production bridge mode remains
`.automationCommandOwned`.

Facade sync decisions live in `LiveRuntimeFacadeSyncPolicy`. New Runtime domain
migrations must update that policy instead of adding another `shouldSync...`
function to `ViewModel.swift`.

Source string tests are allowed as architecture gates for these boundaries, but
they are not substitutes for behavior tests. Result-returning automation query
migration remains blocked until the Runtime effect/port infrastructure split
tests, bridge slimming tests, runtime wiring
extraction tests, Runtime facade/snapshot extraction tests, ViewModel
encapsulation gates, Projection/PPT/Support facade extraction tests,
media/assets extraction tests, and the existing runtime ownership tests pass.
Result-returning query migration must also wait for the Projection/PPT
encapsulation gates that hide raw output-window, EventTap, WPS monitor, BGM
timer-generation, and audio-routing transition storage behind accessors.

## Effect Wiring

| Port | Production state | Ownership meaning |
| --- | --- | --- |
| `media` | wired | Runtime media playback effects execute through the ViewModel bridge to `AVPlayerCoordinator`. |
| `bgm` | wired | Runtime BGM playback effects execute through the ViewModel bridge to `AVAudioPlayer` with an `AVPlayer` fallback. |
| `bgmTimer` | wired | Runtime BGM timer effects start and stop the ViewModel-owned timer implementation by generation. |
| `panicDelay` | wired | Runtime schedules delayed Panic BGM pause through `PanicDelayPort`; the ViewModel-owned task implementation dispatches elapsed callbacks through `LiveRuntimeEffectExecutionContext` and clears task/generation bookkeeping after matching completion or cancelation. |
| `audioRouting` | wired | Runtime audio routing decisions execute through the ViewModel bridge using runtime state. |
| `imageAssets` | wired | Runtime can request background and corner-logo image reloads. |
| `persistence` | wired | Runtime can persist selected preference updates. |
| `projection` | wired | Runtime projection start/stop effects execute through the ViewModel bridge to the concrete output window controller. |
| `ppt` | wired | Runtime PPT EventTap lifecycle effects execute through the ViewModel bridge to the concrete CGEventTap implementation. |
| `automationNotice` | wired | Runtime automation notice show and expiry effects execute through the ViewModel bridge to the concrete facade notice field. |
| `support` | wired | Runtime support ingress notifies the ViewModel bridge to sync the concrete `supportEvents` facade from `runtime.state.support`. |
| `automation` | wired | Runtime fire-and-forget command execution requests execute through the ViewModel bridge to concrete AppleScript command running. |

## Media Playback Boundary

Media playback is runtime-owned. ViewModel validates sources, owns the program
queue, and sets UI-facing current program state, but media load/play/pause/
restart/stop/seek effects execute through `MediaPlaybackPort`. Seek-to-start and
seek-to-end are distinct runtime actions; restart outside Panic remains the
migrated operator action that seeks to the beginning and starts playback.
Restart during Panic is safety-gated: Runtime emits `.seekMediaToStart` instead
of `.restartMedia`, keeping Runtime state and the real media port aligned with
emergency blackout. Operator media toggle during Panic can only pause
already-playing media; if media is stopped, it is a no-op and must not emit
`.playMedia`. Media program selection during Panic loads without playing, and
`operatorResumedMediaAfterPanic` no-ops until Panic is inactive. Future work:
extract `MediaRuntimeReducer.swift` after these Panic media safety gates are
locked.

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
BGM Runtime reducer mechanics live in `Runtime/BGMRuntimeReducer.swift`.
`LiveRuntimeReducer.swift` keeps BGM ownership guards and delegates BGM actions
to that domain reducer. The BGM reducer owns selection, stop/fade, seek,
play-mode, progress, adjacent selection, reached-end, failure, and Panic
pause/resume mutation/effect logic. BGM play-mode changes require explicit
`.bgm` ownership before they mutate Runtime state or emit persistence effects.
It may call Runtime audio helpers
`syncAudioRoutingContextFromMirrorState` and `recalculateAudio` until a
dedicated `AudioRuntimeReducer` extraction is planned as future work.

Production uses `BGMPlaybackPort` and `BGMTimerPort` effects for concrete
playback and timer operations. ViewModel bridges those effects to
`AVAudioPlayer`, the `AVPlayer` fallback, and the existing timer implementation.
Runtime BGM effects are generation-guarded so stale play, stop, timer, progress,
finish, and failure callbacks cannot mutate the current track. During Panic,
direct BGM selection and adjacent BGM selection through next/previous cue and
stop the selected track instead of starting audible playback; Panic
orchestration itself and BGM Panic snapshot mutation remain Runtime-owned. BGM
terminal/changing paths mark matching Panic snapshots stopped through
`PanicRuntimeReducer`, while normal Panic BGM pause preserves resume
eligibility.
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

Runtime owns BGM fade-in and fade-out behavior. Manual BGM stop uses
`LiveRuntimeEnvironment.liveAudioFadeDuration`; BGM fade-in and fade-out use
the same configured live fade duration unless a specific policy says otherwise.
Runtime may keep a current BGM item selected while stopped. BGM fallback cleanup
does not require the current track to be nil; it releases the fallback player
after the fade when the generation still matches and BGM is no longer playing.

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
`ViewModel+ProjectionOutput.swift` bridges those effects to
`OutputWindowController`, `OutputView` mounting, `ProjectionService` screen
lookup, projection support-event generation, and the external-display observer
facade. The concrete output window controller remains behind the projection
port and is not runtime-owned. Main `ViewModel.swift` must not own these
Projection output method bodies.
Raw output-window show/hide side effects are internal ProjectionPort
implementation details and must not be exposed as direct ViewModel bypasses.

Projection start failure is distinct from display loss.
`projectionStartFailed` records start failure semantics when the operator tries
to start projection but no target screen is available. It sets the start-failed
safety notice and does not emit `stopProjection`.
`projectionExternalDisplayLost` is only for broadcasting loss after projection
was already active; it sets the display-lost safety notice and emits
`stopProjection` only when the previous state was broadcasting.

Support production ingress is runtime-owned. In `.projectionOwned`,
projection reducer actions must not write support storage directly; support
entries for projection start, stop, fail-closed, and display-lost events are
still generated by ViewModel after Runtime transitions and enter Runtime through
`.supportEventRecorded`. `.supportEventRecorded` remains the only reducer action
that writes support storage in production.

## PPT EventTap Boundary

PPT EventTap lifecycle is runtime-owned. Runtime owns `state.ppt.isRequested`,
`state.ppt.isEventTapActive`, `state.ppt.lastFailureReason`, operator set/toggle
decisions, and `startPPTEventTap` / `stopPPTEventTap` effects. The UI facade
`isPageInterceptEnabled` is a projection from `state.ppt.isEventTapActive`, so
PPT appears ON only after the EventTap started callback is accepted.

Production uses `PPTEventTapPort` effects for EventTap lifecycle side effects.
`ViewModel+PPTEventTap.swift` bridges those effects to the existing CGEventTap
fields: `pageInterceptEventTap`, `pageInterceptRunLoopSource`, and
`pageInterceptSelfRefcon`. The actual key forwarding, WPS/Keynote automation,
permission alert UI, telemetry, and PPT support event generation remain
ViewModel-owned in that facade file. Main `ViewModel.swift` must not own PPT
EventTap or key-forwarding method bodies.

PPT start success records support only after `pptEventTapStarted`. PPT start
failure dispatches `pptEventTapFailed`, rolls back requested and active state,
keeps the facade OFF, records failure support only, and must not record
`pptModeChanged isOn=true`. PPT stop dispatches `pptEventTapStopped` and records
OFF support once after Runtime state is known. In `.pptOwned`, PPT reducer
actions must not write support storage directly; `.supportEventRecorded` remains
the only reducer action that writes support storage in production.

## Automation Notice Boundary

Automation notice lifecycle is runtime-owned. Runtime owns
`state.automation.notice`, `state.automation.suppressionUntilByAction`, notice
creation, throttling, expiry, dismissal, and `showAutomationNotice` /
`expireAutomationNotice` effects. Production uses `AutomationNoticePort` effects
for notice surface side effects. ViewModel bridges those effects to the existing
`automationRuntimeNotice` facade field and dispatches expiry callbacks back into
Runtime.

Automation notice expiry tasks are ID-bound. Showing a replacement notice,
dismissing the current notice, manually expiring it, clearing Runtime notice
state, or cleaning up the ViewModel cancels the pending expiry task. A scheduled
expiry callback dispatches `.automationNoticeExpired` only while the current
Runtime notice ID still matches the scheduled ID, so stale expiry callbacks
cannot clear a newer notice.

`automationNoticeRequested` and `automationNoticeExpired` are internal lifecycle
actions and are suppressed from the operator-facing Runtime action log.
`automationFailed` remains the meaningful system event for automation failure
diagnostics, and `automationNoticeDismissed` remains logged because it represents
an operator-visible dismissal.

Automation command execution is runtime-owned only for fire-and-forget
AppleScript commands. Runtime owns `.automationScriptRequested`, action-log
redaction for that request, and the `.runAppleScript` effect behind the
Automation command domain. Production wires the `automation` port for command
execution in `.programActivationOwned`.

Presentation query lifecycle is runtime-owned for operator-initiated Keynote
scan requests. Runtime stores the active request ID, emits
`.scanPresentationQuery`, accepts completed/failed callbacks through
`LiveRuntimeEffectExecutionContext`, and stores the latest result or sanitized
failure until ViewModel consumes it exactly once.

ViewModel still owns AppleScript source construction, concrete
`AppleScriptRunner.run`, failure handling, support event generation decisions,
and dispatching `.automationFailed` for Runtime notices. ViewModel also owns
presentation query result consumption: program queue item building, queue
mutation, failure support generation, and failure notice dispatch. WPS fallback
branching, PPT key forwarding, WPS key forwarding, automation permission modal
alerts, telemetry, and non-command automation flows remain ViewModel-owned.
Presentation automation command/query boundary code lives in
`ViewModel+PresentationAutomation.swift`; automation failure and notice facade
code lives in `ViewModel+AutomationFailure.swift`.
Runtime-generated automation notice failures must not write Support storage in
`.automationNoticeOwned`, `.supportOwned`, `.automationCommandOwned`,
`.presentationQueryOwned`, `.programQueueOwned`, `.programSelectionOwned`,
`.programActivationOwned`, or `.panicOwned`; support entries for automation failures are still
generated by ViewModel and enter runtime storage only through
`.supportEventRecorded`.

## Support Boundary

Support storage and production ingress are runtime-owned. Runtime owns
`state.support.events`, `state.support.coalescedCounts`, and
`state.support.eventLimit`, including redaction, coalescing, priority retention,
and trimming. Production uses `.panicOwned` and wires
`SupportEventPort`.
`SupportRuntimeState.record` returns the exact accepted event stored in
`state.support.events`, including a coalesced replacement event, or `nil` when
the incoming event is trimmed immediately by priority retention. The reducer
emits `.recordSupportEvent` only for that accepted event, so the port never
receives a raw, rejected, or uncoalesced ingress payload.

`ViewModel+SupportFacade.swift` owns `recordSupportEvent(...)`, which remains
the canonical facade call site for
existing UI, projection, PPT, BGM, automation failure, preflight, and overlay
event generation. It must only build the `LiveSupportEvent`, dispatch
`.supportEventRecorded`, and sync `supportEvents` from Runtime. It must not
append support events directly, perform local redaction/coalescing/trimming,
write UserDefaults, run telemetry, or execute automation. The production
`SupportEventPort` is notification-only and exists to sync the concrete
`supportEvents` facade after Runtime state changes.

`.supportEventRecorded` is support ingress, not operator intent, and is
suppressed from the operator-facing Runtime action log. Meaningful operator and
system actions such as projection toggles, `automationFailed`, and
`automationNoticeDismissed` remain logged. Reducer-generated support remains
disabled in production migrated domains; ViewModel call sites still decide
which Support events exist. Automation command execution is wired through the
`automation` port in `.programActivationOwned`, but Support generation remains
ViewModel-owned.

## Next Migration Gate

Program activation/switching side effects, broader automation query ownership,
source-validation migration, invalid-deck validation migration, and
key-forwarding Automation migration remain blocked. The next migration may
proceed only after Audio, Media, BGM, Projection, PPT, Automation notice,
Support, Automation command, Presentation query, Program queue storage, current
program selection, and Program activation lifecycle ownership and hardening
tests pass,
cumulative bridge tests pass, bridge mode explicitness tests pass, explicit
runtime-store tests pass, no implicit full runtime remains, the target domain
port is connected in a dedicated PR, and ViewModel no longer owns that target
domain's migrated side effects in that future PR.
Automation execution migration remains blocked.

Remaining migration boundaries:
- AppleScript source construction remains ViewModel-owned.
- Keynote/WPS result-returning AppleScript queries and scans remain ViewModel-owned.
- WPS fallback branching remains ViewModel-owned.
- PPT key forwarding and WPS key forwarding remain ViewModel-owned.
- Support event generation call sites and telemetry remain ViewModel-owned.
