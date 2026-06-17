# Live Mode Simplicity Rules

Live mode is the operator surface for an active show. It should stay narrow,
fast, and action-oriented. Setup, library editing, and system configuration
belong outside the live surface unless a future PR explicitly changes that
product boundary.

## Allowed live actions

- Switch source.
- Take next.
- Toggle main media playback.
- Restart current media.
- Toggle projection.
- Toggle panic.
- Toggle fade-to-black.
- Toggle speaker mode.
- Toggle PPT mode.
- Adjust master, media, and BGM audio controls.
- Play or pause existing BGM.
- Select previous BGM.
- Select next BGM.
- Select existing BGM.
- Select existing standby wallpapers.
- Trigger existing overlay presets.

## Forbidden configuration surfaces

- Importing or adding program sources.
- Editing the program queue structure.
- Editing BGM library metadata.
- Editing overlay preset definitions.
- Editing automation settings.
- Editing auto-advance or auto-next preferences.
- Editing release, build, debug, or developer settings.
- Adding new setup-only panels to the live rail.

## Policy model

- Live mode simplicity is independent of runtime migration.
- Runtime migration PRs must not add live controls.
- Runtime bridge explicitness PRs do not alter live controls.
- Runtime bridge slimming does not add live controls. Code simplicity is part
  of product simplicity: bridge adapters and sync policies should move out of
  the live ViewModel surface without changing the operator workflow.
- Runtime wiring extraction does not add live controls. It only moves concrete
  ViewModel Runtime port handler wiring into `ViewModel+RuntimeWiring.swift`;
  Live mode remains execution-only.
- Runtime facade/snapshot extraction does not add live controls. It only moves
  Runtime dispatch/callback bridge code, facade-to-runtime snapshot building,
  and runtime-to-facade projection helpers out of `ViewModel.swift`; Live mode
  remains execution-only.
- ViewModel encapsulation cleanup does not add live controls. It only restores
  private storage boundaries and moves core model types into `Models/`; Live
  mode remains execution-only and code simplicity remains part of product
  simplicity.
- Persistence store extraction does not add live controls. It only moves
  UserDefaults save/load mechanics, key ownership, repaired image paths, and
  missing-file support event returns into `SwitcherPersistenceStore`; Live mode
  remains execution-only and code simplicity remains part of product
  simplicity.
- Persistence store hardening does not add live controls. It only makes
  persistence loading read-only, moves repair writes behind explicit
  `applyRepairs(...)`, and keeps persistence facade code in
  `ViewModel+Persistence.swift`; Live mode remains execution-only and code
  simplicity remains part of product simplicity.
- Program and presentation facade extraction does not add live controls. It
  only moves Program queue methods to `ViewModel+ProgramQueue.swift`,
  presentation automation command/query boundary methods to
  `ViewModel+PresentationAutomation.swift`, and automation failure/notice
  facade methods to `ViewModel+AutomationFailure.swift`; Live mode remains
  execution-only and code simplicity remains part of product simplicity.
- Audio and BGM facade extraction does not add live controls. It only moves
  audio routing bridge code to `ViewModel+AudioRouting.swift`, BGM runtime
  playback bridge code to `ViewModel+BGMRuntimePlayback.swift`, and BGM library
  editing/operator selection facade code to `ViewModel+BGMControls.swift`;
  Live mode remains execution-only and code simplicity remains part of product
  simplicity.
- Projection and PPT facade extraction does not add live controls. It only
  moves projection output/window/support side effects to
  `ViewModel+ProjectionOutput.swift`, PPT EventTap/key-forwarding side effects
  to `ViewModel+PPTEventTap.swift`, and the Support ingress facade to
  `ViewModel+SupportFacade.swift`; Live mode remains execution-only and code
  simplicity remains part of product simplicity.
- Projection and PPT encapsulation cleanup does not add live controls. It only
  hides raw output-window, EventTap, WPS monitor, BGM timer-generation, and
  audio-routing transition storage behind narrow ViewModel accessors before any
  future query migration; Live mode remains execution-only.
- Media and asset facade extraction does not add live controls. It only moves
  media callback/HTML presentation methods to `ViewModel+MediaPlayback.swift`
  and wallpaper/corner-logo library methods to `ViewModel+Assets.swift`; Live
  mode remains execution-only and code simplicity remains part of product
  simplicity.
- ViewModel hook consolidation and Program activation side-effect boundary
  cleanup do not add live controls. Production activation side effects are
  grouped under `ProgramActivationSideEffectHandlers`, test-only seams are
  grouped under `SwitcherViewModelTestHooks`, and media seek/restart remains on
  Runtime media actions without action-handler bypasses; Live mode remains
  execution-only and code simplicity remains part of product simplicity.
- Program activation phase-plan hardening does not add live controls or change
  switching behavior. It only makes activation order explicit: pre-selection
  effects, Runtime current-program selection, current-program facade projection,
  then post-selection effects. Runtime remains the selected-program source of
  truth.
- Program activation runtime lifecycle migration does not add live controls or
  change switching behavior. It only moves activation request/completion
  lifecycle and effect dispatch to Runtime; source availability checks, invalid
  deck validation, and concrete activation side effects remain ViewModel-owned.
- Program activation runtime hardening does not add live controls or change
  switching behavior. Runtime request ID gates activation side effects, and
  Runtime selection acceptance gates post-selection side effects.
- Program Activation Runtime reducer extraction does not add live controls or
  change switching behavior. It only keeps Runtime reducer files domain-scoped
  by moving activation request/completion lifecycle mutation into
  `ProgramActivationRuntimeReducer`.
- Panic transition policy hardening does not add live controls or change
  emergency behavior. It only moves snapshot, media pause, delayed BGM pause,
  and resume decisions into `PanicTransitionPolicy`; the BGM fade delay is
  unchanged, and emergency behavior must stay deterministic and tested.
- Runtime Panic delay readiness does not add live controls or change emergency
  behavior. It only lets Runtime represent delayed Panic BGM pause through
  `PanicDelayPort` and `PanicRuntimeReducer`; production now wires
  `panicDelay`, and delayed BGM pause remains a behavior invariant.
- Panic runtime facade hardening does not add live controls or change emergency
  behavior. Runtime-owned emergency state is the single source of truth;
  `isPanicMode` and `panicPlaybackSnapshot` are facade projections, and audio
  routing snapshots must not use stale facade Panic state.
- Presentation query service extraction does not add live controls. It only
  moves concrete presentation query execution into `PresentationQueryService`
  and query-result normalization/dedupe into `PresentationQueryResultBuilder`;
  result-returning queries remain ViewModel-owned until a dedicated query
  ID/callback Runtime migration is approved.
- Presentation query service hardening does not add live controls. It only
  removes model-layer dependencies on `KeynoteController`, introduces
  `PresentationQueryResult` as the query payload, and isolates title cleanup in
  `PresentationWindowTitlePolicy`; Live mode remains execution-only and code
  simplicity remains part of product simplicity.
- Presentation Query Runtime reducer extraction does not add live controls or
  change query behavior. It keeps Runtime reducer files domain-scoped by moving
  request/completion/failure/consume lifecycle routing into
  `PresentationQueryRuntimeReducer`; query result normalization and consumption
  side effects remain ViewModel-owned.
- Runtime infrastructure domain hardening does not add live controls. It only
  gives image asset loading and preference persistence their own Runtime bridge
  domains, keeps production connected ports unchanged, and keeps
  result-returning automation queries ViewModel-owned until a dedicated query
  migration is approved.
- Runtime effect/port infrastructure splitting does not add live controls. It
  only separates the Runtime effect enum, effect policy, port kind enum, port
  protocols, effect runner, closure adapters, and production port bundle into
  focused files; Live mode remains execution-only and query migration remains
  blocked.
- Runtime effect callback readiness does not add live controls. It only gives
  effect execution an explicit current-state and dispatch context for future
  callback-capable ports; callback paths must stay explicit and testable, Live
  mode remains execution-only, and result-returning queries remain
  ViewModel-owned.
- BGM runtime migration does not add live controls.
- BGM runtime hardening does not add live controls; it only tightens ownership,
  callback identity, timer generation, seek, loop-mode, and fallback execution
  paths behind the existing BGM transport.
- BGM runtime cleanup-gate hardening does not change the Live Mode surface.
  It only separates current-player generation-guarded tasks from retired-player
  cleanup and tightens callback, timer, and port contracts behind existing BGM
  controls.
- BGM fade-out runtime fixes do not add live controls; they only restore
  configured fade-out behavior behind existing BGM stop/toggle actions. BGM
  library editing remains setup-only.
- BGM Runtime reducer extraction does not add live controls or change BGM
  behavior. It only keeps Runtime reducer files domain-scoped by moving BGM
  mutation mechanics to `BGMRuntimeReducer`.
- BGM Runtime reducer hardening does not add live controls. Existing BGM
  next/previous controls remain allowed, but during Panic their Runtime behavior
  is safety-critical: they cue/stop the selected track instead of starting
  playback, and reducer files stay domain-scoped.
- Preferences Runtime reducer extraction does not add live controls or change
  preference behavior. It only keeps Runtime reducer files domain-scoped by
  moving persisted setting mutation mechanics to `PreferencesRuntimeReducer`,
  while wallpaper and corner-logo URL updates remain behind the existing Setup
  flow and infrastructure guards.
- Automation Command Runtime reducer extraction does not add live controls. It
  only moves command effect emission into `AutomationCommandRuntimeReducer` and
  suppresses unnecessary audio-input sync for `automationScriptRequested`;
  AppleScript source construction, WPS fallback branching, and key forwarding
  remain outside the live surface.
- Dead Runtime action pruning does not add live controls or change user
  behavior. It only removes no-op Runtime actions from the action surface;
  BGM preparation remains behind existing BGM effects/callbacks, Panic delayed
  BGM pause remains behind `panicBGMPauseDelayElapsed`, and Live mode remains an
  execution surface with the same operator controls.
- Facade current-program compatibility action pruning does not add live
  controls or change user behavior. Current Program selection remains behind
  real Runtime selection/clear actions, Runtime action surface stays small, and
  Live mode keeps the same operator controls.
- Runtime-owned snapshot source hardening does not add live controls or change
  user behavior. It only prevents stale facade state from overwriting
  Runtime-owned media, current-program, and audio-routing truth.
- Runtime-owned BGM snapshot source hardening does not add live controls or
  change user behavior. It only prevents stale facade BGM playback/play-mode
  state from overwriting Runtime-owned BGM truth while keeping BGM library
  items ViewModel-owned.
- Runtime-owned projection snapshot source hardening does not add live controls
  or change user behavior. It only prevents stale ViewModel external-display
  facade values from overwriting Runtime-owned projection truth.
- Projection facade sync hardening does not add live controls or change user
  workflow. It only makes Runtime-owned projection availability, broadcasting,
  and safety notice visible through the existing ViewModel facade.
- Runtime callback ownership guard hardening does not add live controls or
  change production callback behavior. It only makes async Media/BGM callbacks
  obey existing Runtime ownership before mutating state.
- Program Queue Runtime reducer extraction does not add live controls or change
  Program Queue behavior. It only keeps Runtime reducer files domain-scoped by
  moving Program Queue mutation routing to `ProgramQueueRuntimeReducer`.
- Media restart Panic hardening does not add live controls. Existing restart
  remains available, but emergency safety overrides playback: during Panic,
  Runtime seeks/cues media to start without emitting a restart/play effect, and
  Runtime state must match the real player behavior.
- Media playback Panic gate hardening does not add live controls. Panic safety
  overrides all media start actions: operator toggle cannot start media during
  Panic, resume-after-Panic is ignored until Panic is inactive, and Runtime state
  must match the real player behavior.
- Media playback callback Panic hardening does not add live controls. Panic
  safety overrides stale media playback callbacks: `mediaPlaybackChanged(true)`
  cannot mark Runtime media playing during Panic and must keep Runtime and the
  concrete player aligned through a pause effect.
- Projection runtime migration does not add live controls. Existing projection
  start/stop remains the only allowed projection action in Live mode.
- Projection runtime hardening does not add live controls; it only separates
  start-failure and display-lost semantics behind the existing projection
  action.
- Projection configuration must not move into Live mode.
- PPT runtime migration does not add live controls; the existing PPT toggle
  remains the only allowed live PPT action.
- PPT facade requested-state sync hardening does not add live controls or
  change workflow. It only makes Runtime-owned requested-or-active PPT state
  visible through the existing `isPageInterceptEnabled` facade while the
  EventTap start callback is pending.
- PPT setup/configuration and key-forwarding implementation details must not
  move into Live mode.
- Automation notice runtime migration does not add live controls. Automation
  failures appear through the existing notice surface, and no live-mode
  configuration surface is added.
- Automation notice runtime hardening does not add live controls. Expiry
  cleanup, stale-expiry guards, suppression cleanup, and action-log filtering
  stay behind the existing notice surface.
- Automation command runtime migration does not add live controls. It only moves
  existing fire-and-forget AppleScript command execution behind Runtime; WPS
  fallback branching, result-returning queries, scans, and PPT/WPS key
  forwarding remain ViewModel-owned.
- Automation command runtime hardening does not add live controls. It only
  redacts recorded command effects, sanitizes Runtime failure action messages,
  and replaces sleep-based command tests with deterministic completion hooks.
- BGM library editing remains forbidden in Live mode.
- No live-mode UI controls were added for the Media runtime migration or follow-up hardening; these changes only adjust media ownership and execution paths.
- `LiveModeSimplicityPolicy` is the source-level policy model for allowed live
  actions, primary action count, and forbidden configuration surfaces.
- `LiveModeSimplicityPolicy` is the code-level gate for live-mode limits,
  including primary action count, live rail card count, and visible BGM rows.
- Any new live action must update `LiveModeActionKind` and this document.
- Any new live control must be reviewed against `LiveModeSimplicityPolicy`.
- Configuration surfaces are forbidden in Live mode even when the same action is
  available in Setup mode.
- Any new live configuration surface is forbidden unless architecture review
  changes the policy.
- Live Mode remains an execution surface, not a setup/configuration surface.

## Review checklist

- Every visible live control must perform a real action in the current app.
- Any new live control must map to an allowed live action above.
- The first live viewport must prioritize source switching, output state,
  media restart/playback, audio, and BGM transport.
- Setup-only controls must stay in setup views, toolbars, or dedicated
  preference surfaces.
- Current authoritative runtime domains: Audio, Media playback, BGM playback,
  Projection output, PPT EventTap lifecycle, Automation notice lifecycle,
  Support ingress/storage, Automation command execution, Presentation query
  lifecycle, Program queue storage/mutation, current program selection, and
  Program activation request/completion lifecycle, and Panic transition
  orchestration.
- Mirror-only live domains and ViewModel-owned live domains are broader
  Automation flows, Program activation source validation/planning, concrete
  activation side effects, fade-to-black visual state, and Panic support-event
  generation. PPT key forwarding, WPS fallback branching, scans, Support event
  production, source validation, invalid-deck alerts, live activation side
  effects, and telemetry remain ViewModel-owned implementation details.
- Runtime-backed actions must respect the production `.panicOwned`
  bridge mode:
  media playback, BGM playback/timer, projection start/stop, PPT EventTap
  lifecycle, automation notices, Support ingress, audio routing, image assets,
  persistence, fire-and-forget automation command execution, presentation
  queries, Program queue storage/mutation, and current program selection may
  execute; Program activation request/completion lifecycle may execute through
  Runtime while source validation, plan construction, concrete activation side
  effects, scans, WPS fallback branching, and PPT/WPS key forwarding remain
  ViewModel-owned.
- Program activation facade extraction does not add live controls or change
  switching behavior. Code simplicity is part of product simplicity: the live
  action stays "select a program" while planning is pure and execution remains
  in the ViewModel activation facade.
- Program activation hardening does not add live controls or change switching
  behavior. It only makes activation ordering behavior-tested, isolates pure
  source availability classification, and moves current-program media transport
  methods out of the activation facade.
- Source queue count in runtime state must match the ViewModel queue count;
  a current item outside the queue belongs in `currentDetachedItem`.
