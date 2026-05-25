# BGM Observation RFC

## Decision

Do not migrate `SwitcherViewModel` to Swift Observation in the BGM performance PR. Ship the smaller isolation first:

- throttle BGM progress updates to 10fps
- move BGM progress state into `BGMProgressStore`
- let only the BGM progress bar observe that store

## Reasoning

`SwitcherViewModel` still owns playback, projection, preflight, overlays, keyboard interception, and support reporting. Converting the whole model from `ObservableObject` to `@Observable` would touch almost every SwiftUI surface and make a targeted runtime fix harder to review.

The high-frequency problem is currently narrow: BGM playback updates `progress`, `currentTime`, and `duration` on every timer tick. Isolating those three values removes the most avoidable whole-console invalidation without changing playback semantics.

## Follow-Up Epic

A full Swift Observation migration can be evaluated later as a dedicated epic:

- replace `ObservableObject` / `@Published` on `SwitcherViewModel`
- move views from `@EnvironmentObject` to Swift Observation environment access
- validate retained-tab behavior, support events, playback timers, and projection safety
- compare body invalidation and main-thread time before and after

This should not be bundled with localized copy cleanup or live-mode UI work.
