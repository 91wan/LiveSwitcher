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

- `LiveModeSimplicityPolicy` is the source-level policy model for allowed live
  actions, primary action count, and forbidden configuration surfaces.
- Any new live action must update `LiveModeActionKind` and this document.
- Any new live control must be reviewed against `LiveModeSimplicityPolicy`.
- Configuration surfaces are forbidden in Live mode even when the same action is
  available in Setup mode.

## Review checklist

- Every visible live control must perform a real action in the current app.
- Any new live control must map to an allowed live action above.
- The first live viewport must prioritize source switching, output state,
  media restart/playback, audio, and BGM transport.
- Setup-only controls must stay in setup views, toolbars, or dedicated
  preference surfaces.
- Current authoritative runtime domain: Audio only.
- Mirror-only live domains are Program, Media, BGM, Panic, PPT, Projection,
  and Automation. Live controls for those domains must use ViewModel-owned
  flows and must not rely on runtime operator actions to mutate real state.
- Runtime-backed actions must respect the production `.audioOwned` bridge mode:
  audio routing, image assets, and persistence may execute; unowned media, BGM,
  projection, PPT, automation, timer, notice, and support effects must not.
- Source queue count in runtime state must match the ViewModel queue count;
  a current item outside the queue belongs in `currentDetachedItem`.
