# Live Mode Simplicity Rules

## Product boundary

Live Mode remains an execution surface. It is not an editor, setup screen, importer, debug console, or migration staging area.

Live mode simplicity is independent of runtime migration: runtime ownership PRs may move state and side effects behind Runtime, but Runtime migration PRs must not add live controls.

Current authoritative runtime domains: Audio, Media playback, BGM playback; Projection output, PPT EventTap lifecycle; Support ingress/storage. Mirror-only live domains must remain read/project-only until their ownership contract says otherwise.

## Allowed live actions

Allowed live actions are the complete code-level gate. Every live control must map to one of these labels:

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

Projection runtime migration does not add live controls. PPT runtime migration does not add live controls. Program Activation Runtime reducer extraction does not add live controls. Automation Command Runtime reducer extraction does not add live controls. Dead Runtime action pruning does not add live controls. Facade current-program compatibility action pruning does not add live controls. Runtime-owned snapshot source hardening does not add live controls. Runtime-owned projection snapshot source hardening does not add live controls.

## Forbidden live configuration

Forbidden configuration surfaces must stay outside Live Mode:

- Importing or adding program sources
- Editing the program queue structure
- Editing BGM library metadata
- Editing overlay preset definitions
- Editing automation settings
- Editing auto-advance or auto-next preferences
- Editing release, build, debug, or developer settings

Projection configuration must not move into Live mode. PPT setup/configuration and key-forwarding implementation details must not move into Live Mode. WPS fallback branching remains a ViewModel-owned automation detail outside Live Mode controls.

## Runtime/UI separation rules

Live controls dispatch existing actions through the ViewModel boundary. Runtime-owned domains publish snapshots back to the facade; UI code must not mutate Runtime-owned storage directly.

Adding a new Live Mode control requires both policy approval and documentation in this file. If the control configures source data, library metadata, automation, projection setup, PPT setup, release/debug settings, or persisted preferences, it belongs outside Live Mode.

## Complexity budget

The main visible action set must stay small: primary actions stay within the policy limit, the live rail stays within its card limit, and visible BGM rows stay within their policy limit.

## Review checklist

- Does the change keep Live Mode as an execution surface?
- Is every control in Allowed live actions?
- Is every setup or editing flow excluded by Forbidden configuration surfaces?
- Does the change preserve the code-level gate in `LiveModeSimplicityPolicy`?
- Does it avoid adding controls while moving Runtime ownership?

## Architecture freeze

This document is the compact freeze for Live Mode. Extend the code policy first, then update this document, then add behavior tests only for real user-visible behavior.
