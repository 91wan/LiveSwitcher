# Post-Stable Stop Condition

This document freezes the end state for the post-v0.5.0 internal cleanup
stream. It exists to stop cleanup work, not to create another refactor lane.

## Stop Rule

Stop post-stable refactor when all of these are true:

- Once the complexity allowlist is empty or contains only accepted exceptions.
- Once source-string debt is 0.
- Once there is no P0/P1 or user-visible stability fix.

For the current v0.5.0 stream, those conditions mean further cleanup PRs should
stop unless a concrete production-risk contract reopens the scope.

## Allowed Future Work

After the stop rule is reached, only these scopes may reopen post-stable work:

- P0/P1.
- release delivery issue.
- notarization / installation.
- user-visible stability.
- clearly bounded tech-debt with measurable risk reduction.

Each reopened scope needs a narrow contract, explicit acceptance, and fresh
verification evidence.

## Non-Goals

Do not use this document as permission to continue refactoring.

- No production code changes.
- No new UI.
- No release changes.
- No new controls, modes, import types, playback behavior, projection behavior,
  or automation behavior.

Documentation and tests may enforce this stop rule, but they must not expand
the product surface or publish a new release.
