# LiveSwitcher v0.6.0 Release Readiness

This document records the v0.6.0 release-readiness state for the phone LAN
remote feature stream. It is prepared in a Draft PR and does not publish the
release by itself.

This readiness PR must stay Draft until the maintainer finishes review. Do not
tag `v0.6.0`, do not create a GitHub Release, and do not upload release assets
from this PR. The final release still requires explicit user approval after the
readiness PR is reviewed and merged.

## Candidate Scope

v0.6.0 adds the phone LAN remote-control MVP and the refreshed app icon. The
remote remains a browser-based local network surface, not a second switcher
console.

Included remote scope:

- LAN-only Web remote served by LiveSwitcher.
- Off by default; the Mac operator enables each session.
- Token-protected pairing URL with the token kept out of logs and support
  reports.
- Single controller client; second phone or second tab is read-only.
- Approved Live Mode commands only: Take Next, media play/pause, return current
  media to start, BGM play/pause/previous/next, speaker mode, Fade To Black,
  and Panic.
- Issue #448 is included: phone command feedback is action-specific and does
  not expose program titles, BGM titles, token values, client ids, nonces, IP
  addresses, or local file paths.
- Issue #450 is included: phone program/media color roles align Take Next,
  current media play/pause, return-to-start, current program, and next program
  while keeping BGM controls visually distinct.
- Issue #449 is not included: guarded Previous Item remains out of scope for
  v0.6.0 because it would add a new remote command surface.
- Dangerous commands require long-press plus server confirmation nonce.
- Setup diagnostics for same Wi-Fi, dedicated router, Mac hotspot, AP
  isolation, missing local network address, port failure, and network changes.

Still out of scope:

- Bluetooth remote.
- Native iOS or Android app.
- Cloud/public internet remote.
- UPnP, port mapping, or public relay.
- Remote projection toggle.
- Remote arbitrary source switching.
- Remote setup, edit, import, overlay, BGM library, automation, or debug
  surfaces.

## Required Evidence

| Gate | Status | Evidence |
| --- | --- | --- |
| iPhone command no-op fix | PASS | Command ID fallback is UUID-shaped while the server remains strict UUID. |
| Single controller semantics | PASS | Read-only clients cannot execute commands, close sessions, or request danger confirmations. |
| Dangerous nonce hardening | PASS | Nonces bind command kind and controller client id and remain one-time use. |
| HTTP transport hardening | PASS | Request limits, no-store headers, nosniff, CSP, and safe errors are covered. |
| Setup diagnostics | PASS | Same-Wi-Fi, dedicated router, AP isolation, no-address, port-failure, and network-change guidance are in place. |
| Hardware rehearsal PASS | PASS | See `phone-lan-remote-hardware-results-v0.6.0.md`. |
| External output FTB/Panic | PASS | FTB and Panic long-press both accepted with external output black. |
| Issue #448 action-specific command feedback | PASS | Phone success, pending, and failure copy now identifies the command without leaking sensitive values. |
| Issue #450 program/media color roles | PASS | Take Next, current media controls, current program, and next program share a program/media role; BGM controls remain distinct. |
| Final phone UI smoke after #448 / #450 | PASS | See [`phone-lan-remote-hardware-results-v0.6.0.md`](phone-lan-remote-hardware-results-v0.6.0.md#final-phone-ui-smoke-after-448--450); operator-reported iPhone Safari visual acceptance is recorded after #451/#452. |
| Issue #449 Previous Item remains out of scope | PASS | No previous-item remote command is added to v0.6.0. |
| PR #454 ImageGen / top chrome UI exploration | EXCLUDED | PR #454 is excluded from v0.6.0 and is not part of the release candidate source, release notes, artifact audit, or approval package. |
| 60-minute soak | PASS | Operator accepted the 60-minute phone-connected soak. |
| Android Chrome | BLOCKED as unavailable | Android Chrome was optional when available and no Android-specific device result was provided. |
| Security checklist PASS | PASS | Token, client id, command id, nonce, and read-only policy tests are green. |
| Support/log privacy checklist PASS | PASS | Support/log surfaces must not include token, full phone IP, local paths, raw media filenames, program titles, BGM titles, screenshots, or customer content. |
| Release-candidate build/hash evidence | PENDING | Must be recorded after the Draft PR is ready and before any final tag/release action. |
| Explicit user approval | PENDING | Required after this readiness PR is reviewed. |

## Release Stop Rules

- Keep the PR as a Draft PR until maintainer review is complete.
- Do not tag `v0.6.0` from this PR.
- Do not create a GitHub Release from this PR.
- Do not upload `LiveSwitcher-macOS-v0.6.0.zip` or checksum assets by hand.
- Do not include PR #454 in v0.6.0 release notes, artifact audit, approval
  package, or release candidate source.
- Do not publish v0.6.0 until release-candidate build/hash evidence and
  explicit user approval are both recorded.
- If a final release is approved later, the release tag must point at
  `origin/main`, `VERSION` must equal `0.6.0`, the Release workflow must create
  a draft release, and the generated zip/checksum must be verified.

## Current Decision

The v0.6.0 release-readiness PR is allowed because the hardware rehearsal slice
has passed and the phone LAN remote control feature stream has completed its
required hardening slices. This document only prepares the release gate; it does
not approve the final tag or public release.
