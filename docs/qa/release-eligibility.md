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

## Current Post-v0.5.0 Decision - 2026-06-27

Post-v0.5.0 commits through `4f0fed4` are internal maintenance only. This includes the earlier `d7d0fa...` post-stable cleanup checkpoint referenced by the release-decision contract.

No v0.5.1 release is required.

Patch release remains blocked unless a user-visible production-risk fix or delivery incident fix lands.

## Post-stable allowlist burn-down decision - 2026-06-28

The post-stable ViewModel runtime identity, projection/page-intercept, and
root-shell splits removed the remaining production-code allowlist entry.
The Audio runtime ownership and Persistent runtime load boundary suite splits
removed the remaining oversized test-file allowlist entries. The source-contract
burn-down slices replaced all remaining source-string allowlist rows with
behavior, model, reducer, policy, and fixture-backed gate tests.

The allowlist status after those slices is:

- allowlist rows: 0
- production-code allowlist rows: 0
- test-file allowlist rows: 0
- source-string allowlist rows: 0
- source-string actual total: 0
- source-contains allowlist rows are forbidden

This burn-down is documentation, test, and architecture-gate maintenance only.
It does not change production behavior, UI, playback, projection, Panic, BGM,
automation, packaging, signing, checksum, bundle identifier, app name, or the
minimum macOS version.

No v0.5.1 release is required after this burn-down.

Future post-stable cleanup should stop unless a concrete P0/P1,
release-delivery issue, or user-visible stability fix lands.
