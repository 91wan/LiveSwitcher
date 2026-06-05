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
  Projection output, PPT EventTap lifecycle, Automation notice lifecycle, and
  Support ingress/storage, and Automation command execution.
- Mirror-only live domains are Program queue, Panic, and Automation. PPT key
  forwarding, WPS fallback branching, result-returning queries, scans, Support
  event production, and telemetry remain ViewModel-owned implementation
  details.
- Runtime-backed actions must respect the production `.automationCommandOwned`
  bridge mode:
  media playback, BGM playback/timer, projection start/stop, PPT EventTap
  lifecycle, automation notices, Support ingress, audio routing, image assets,
  persistence, and fire-and-forget automation command execution may execute;
  result-returning queries, scans, WPS fallback branching, and PPT/WPS key
  forwarding must not.
- Source queue count in runtime state must match the ViewModel queue count;
  a current item outside the queue belongs in `currentDetachedItem`.
