# Program Output Transition RFC

## Status

Deferred. This document records the hardware-safe design space for real program output transitions. LS-HW-07 only removes the previous fake controls and dead state; it does not implement transition playback behavior.

## Problem

The removed "program transition" controls changed local monitor animation timing only. They did not create a secondary output layer, did not prepare the next media frame, and did not change hardware output behavior. Keeping those controls implied a feature that the output pipeline did not actually own.

Any future transition feature must be implemented in the runtime-owned output path, not as a View-only animation. It must preserve Panic/FTB priority, generation ownership, monitor/output semantic split, and media transport boundaries.

## Option A: 双播放器 A/B 真交叉溶解

Use two output players. Player A remains live while Player B prerolls the next media or visual source offscreen. After 首帧就绪 is confirmed, the runtime commits a generation token and crossfades opacity or compositor contribution from A to B. If preroll misses its 超时 window, the transition must fail closed and keep the current output stable.

Requirements:

- A runtime transition planner owns source selection, generation token issuance, cancellation, and completion.
- The next player must expose first-frame readiness before any visible output change.
- Panic/FTB 抢占 must cancel pending and active transitions immediately, with deterministic output priority above both players.
- 音频 must be coupled to the same generation. Media audio fade, BGM routing, and source audio handoff cannot be driven by a separate View animation.
- The monitor may preview intent, but the output layer is the source of truth for the live transition.
- 1080p budget: no dropped frames during normal media-to-media transitions on rehearsal hardware.
- 4K budget: prove acceptable thermal, memory, decoder, and compositor load before enabling the path by default.

Tradeoffs:

- Best visual continuity for media-to-media changes.
- Highest implementation and acceptance cost because it doubles decoder/compositor pressure during the transition window.
- Requires explicit failure states for late frames, unsupported sources, and stale generation callbacks.

## Option B: 淡出到壁纸

Use the existing single active output media path. On program change, fade the current media or visual source to the active wallpaper, pause or stop the old source under runtime control, switch the current program, wait for 首帧就绪 when the next source needs media readiness, then fade from wallpaper to the new output. If readiness exceeds the 超时 window, keep wallpaper visible and surface a runtime-safe error state.

Requirements:

- The runtime owns the fade phase machine and generation token.
- Panic/FTB 抢占 cancels every phase and wins output priority.
- 音频 follows the phase plan: fade or duck old media, preserve or restore BGM according to the active audio strategy, and never autoplay audio from a stale generation.
- The monitor can show the selected program and phase state, but it cannot invent an output-only transition.
- 1080p budget: no visible flash, black frame, or wrong-source frame across repeated transitions.
- 4K budget: verify wallpaper fallback avoids decoder overlap and keeps frame pacing stable on rehearsal hardware.

Tradeoffs:

- Lower performance risk and simpler source ownership.
- Visually less seamless than true A/B dissolve.
- Easier to make deterministic under Panic/FTB and hardware rehearsal constraints.

## 硬件验收矩阵

| Scenario | 1080p acceptance | 4K acceptance | Failure handling |
| --- | --- | --- | --- |
| Media to media | No black frame, wrong frame, or audio from stale source | Same, plus stable frame pacing and no thermal runaway | Hold current output for Option A; hold wallpaper for Option B |
| Image or HTML to media | New media appears only after 首帧就绪 | Same, with measured decoder warmup | Timeout keeps previous stable output or wallpaper |
| Media to non-media | Media audio stops according to runtime audio policy | Same | No stale media callback may restart playback |
| Panic/FTB during transition | Panic/FTB 抢占 wins immediately | Same | Cancel generation token and ignore later callbacks |
| Repeated operator changes | Latest generation is the only accepted result | Same | Stale effects are ignored and logged |

## Recommendation

Prototype Option B first because it matches the current single-player output architecture and hardware rehearsal risk profile. Revisit 双播放器 A/B 真交叉溶解 only after the runtime has explicit transition phases, callback ownership checks, and repeatable 1080p/4K hardware evidence.
