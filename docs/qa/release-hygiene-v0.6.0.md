# Release Hygiene - v0.6.0

This document records the release-hygiene state after the final phone LAN remote
UI smoke closeout. It is release-readiness evidence only. It does not approve a
tag, GitHub Release, release asset, checksum publication, or app publication.

## Scope

- v0.6.0 remains focused on the phone LAN remote stream.
- Final phone UI smoke after #448 / #450 is recorded in
  `docs/qa/phone-lan-remote-hardware-results-v0.6.0.md`.
- PR #454 is explicitly excluded from v0.6.0.
- Issue #449 remains backlog and is not part of the v0.6.0 release candidate.
- Android Chrome remains unverified for this closeout.

## Release Stack Boundaries

| Item | State |
| --- | --- |
| #448 action-specific command feedback | Closed by PR #451 |
| #450 media/BGM color grouping | Closed by PR #452 |
| Final phone UI smoke after #448 / #450 | Recorded as operator-reported iPhone Safari PASS |
| #449 guarded previous item command | Deferred to backlog |
| PR #454 ImageGen / top chrome UI exploration | Excluded from v0.6.0 |
| Android Chrome | Unverified |

## Prohibited Actions

- Do not merge PR #454 into v0.6.0.
- Do not rebase PR #454 into the release stack.
- Do not include PR #454 in v0.6.0 release notes, artifact audit, approval
  package, or release candidate source.
- Do not add #449 Previous Item behavior to v0.6.0.
- Do not add new phone remote commands, arbitrary source switching, remote
  projection toggles, remote editing, or remote configuration.
- No tag, GitHub Release, release asset, or checksum publication is approved by this document.

## Privacy Limits

Release hygiene records and support evidence must not include token values,
nonce values, controller client IDs, phone addresses, customer content, real
program names, real BGM names, local file paths, raw diagnostics, screenshots, or
videos.

## Current Release Gate

v0.6.0 remains blocked until the release-readiness PR, artifact audit PR, and
approval package PR are refreshed against the final candidate source and the user
explicitly approves publication.
