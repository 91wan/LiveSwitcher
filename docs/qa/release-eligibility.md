# Release Eligibility Gate

This gate decides whether maintenance work after a stable release should become a public patch release.

## Patch Release Is Allowed

A patch release is allowed only when the change fixes a user-visible production risk or delivery incident:

- P0/P1 crash fixes.
- External display, Panic, blackout, playback, or BGM production incident fixes.
- Release package, checksum, code signing, download, or app launch incident fixes.
- Notarization or critical installation-experience fixes.
- User-visible stability fix that has completed acceptance.

## Patch Release Is Not Allowed

A patch release is not allowed for internal-only maintenance:

- Pure file split work.
- Pure test refactor work.
- Documentation-only changes.
- Complexity gate changes.
- Source-string tests replacement.
- Allowlist burn-down.
- Internal cleanup with no user-visible behavior change.

## Post-Stable Refactor Rule

A post-stable refactor does not require a public release.

Do not automatically publish a patch release after internal refactors, tests, documentation, complexity-budget cleanup, source-string tests replacement, or allowlist burn-down. Reassess release eligibility only when a change meets one of the allowed patch-release conditions above.
