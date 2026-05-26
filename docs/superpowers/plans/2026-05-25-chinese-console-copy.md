# Chinese Console Copy Implementation Plan

## Goal
Converge the operator-facing console copy to Chinese-first wording while preserving standard production terms such as BGM, PPT, HTML, Keynote, dB, and FTB.

## Development Plan
- Update setup chrome, Live mode rail labels, Panic/Preflight/Projection models, Program Monitor status models, and Safety/Preflight titles.
- Keep diagnostics/report persistence keys stable; do not rename persisted enum raw values.
- Add a policy document under `docs/style/i18n-policy.md` to keep future UI strings consistent.
- Update model tests that assert operator-facing copy.

## Verification Plan
- `swift test --filter I18nPolicyTests`
- Targeted model tests for status/toolbar/preflight copy.
- Full release verification chain after the branch is green.
- Screenshot acceptance on Run, Audio, Overlays, and Live where feasible.

## Acceptance Criteria
- No key console header uses `English / 中文` duplicated wording.
- Run/Live chrome uses Chinese labels for source rail, setup tabs, status, and quick rail commands.
- Panic uses `紧急切黑` terminology, not `Blackout` or `Stage black`.
- Preflight top button uses `检查` and Chinese count text.
- Existing playback, projection, audio routing, and persistence behavior are unchanged.
