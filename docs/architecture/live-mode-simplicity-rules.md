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
- ViewModel hook consolidation does not add live controls. It only groups
  production action handlers under `SwitcherViewModelActionHandlers`, groups
  test-only seams under `SwitcherViewModelTestHooks`, and moves PPT mode intent
  methods into `ViewModel+PPTMode.swift`; Live mode remains execution-only and
  code simplicity remains part of product simplicity.
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
- Projection runtime migration does not add live controls. Existing projection
  start/stop remains the only allowed projection action in Live mode.
- Projection runtime hardening does not add live controls; it only separates
  start-failure and display-lost semantics behind the existing projection
  action.
- Projection configuration must not move into Live mode.
- PPT runtime migration does not add live controls; the existing PPT toggle
  remains the only allowed live PPT action.
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
  lifecycle, and Program queue storage/mutation.
- Mirror-only live domains and ViewModel-owned live domains are Panic, broader
  Automation flows, and Program activation/switching. PPT key forwarding,
  WPS fallback branching, scans, Support event production, source validation,
  invalid-deck alerts, live activation side effects, and telemetry remain
  ViewModel-owned implementation details.
- Runtime-backed actions must respect the production `.programQueueOwned`
  bridge mode:
  media playback, BGM playback/timer, projection start/stop, PPT EventTap
  lifecycle, automation notices, Support ingress, audio routing, image assets,
  persistence, fire-and-forget automation command execution, presentation
  queries, and Program queue storage/mutation may execute; scans, WPS fallback
  branching, Program activation/switching, source validation, and PPT/WPS key
  forwarding must not.
- Program activation facade extraction does not add live controls or change
  switching behavior. Code simplicity is part of product simplicity: the live
  action stays "select a program" while planning is pure and execution remains
  in the ViewModel activation facade.
- Source queue count in runtime state must match the ViewModel queue count;
  a current item outside the queue belongs in `currentDetachedItem`.
