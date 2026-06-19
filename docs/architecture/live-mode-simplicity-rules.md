# Live Mode Simplicity Rules

## Product boundary

Live Mode is an execution surface for an active show. Setup owns editing, importing, library management, automation configuration, release/debug settings, and other preparation tasks.

Runtime ownership is defined by `runtime-ownership.md` and executable contract tests. Runtime ownership, extraction, and hardening changes must not expand the Live Mode control surface.

## Allowed live actions

Allowed live actions are the complete code-level gate:

- Switch source
- Take next
- Toggle main media playback
- Restart current media
- Toggle projection
- Toggle panic
- Toggle fade-to-black
- Toggle speaker mode
- Toggle PPT mode
- Play or pause existing BGM
- Select previous BGM
- Select next BGM
- Select existing BGM
- Trigger existing overlay presets
- Select existing standby wallpapers

## Forbidden live configuration

Forbidden configuration surfaces stay outside Live Mode:

- Importing or adding program sources
- Editing the program queue structure
- Editing BGM library metadata
- Editing overlay preset definitions
- Editing automation settings
- Editing auto-advance or auto-next preferences
- Editing release, build, debug, or developer settings

WPS fallback branching remains a ViewModel-owned automation detail, not a Live Mode control.

## Runtime/UI separation rules

Live controls dispatch existing operator actions through the ViewModel boundary. Runtime-owned domains project state back to the facade; facade code must not directly mutate Runtime-owned state.

Adding a new Live Mode control requires policy approval, product-surface review, tests for the visible behavior, and an update to `LiveModeSimplicityPolicy`.

## Architecture freeze

Live Mode stays narrow and execution-only. If a requested control edits setup data or broadens the operator surface, reject it unless a future contract explicitly changes this freeze.
