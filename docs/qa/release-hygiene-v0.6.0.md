# Release Hygiene - v0.6.0

This document records the release-hygiene state for the LiveSwitcher v0.6.0
phone LAN remote feature stream after publication. v0.6.0 is
released-complete: the `v0.6.0` tag points at `origin/main`, the GitHub Release
is published, and the release zip checksum verifies with
`LiveSwitcher-macOS-v0.6.0.zip: OK`.

## LiveSwitcher v0.6.0 Scope

v0.6.0 adds the phone LAN remote-control MVP for live operators who need a
simple, local, browser-based control surface from a phone on the same network.
The remote is not a second switcher console; it exposes only approved Live Mode
execution actions.

The remote control stream includes:

- QR/local URL pairing from the Mac operator surface.
- LAN-only HTTP server with no cloud relay, no public internet remote, no UPnP,
  and no port mapping.
- Session token rotation and token invalidation when remote control is closed.
- Single controller ownership; later clients become read-only.
- Command ID hardening for iPhone Safari on non-secure LAN origins.
- Issue #448 action-specific command feedback, including visible success,
  pending, and failure messages on the phone without leaking sensitive values.
- Issue #450 program/media color roles: Take Next, current media actions,
  current program, and next program share one media/program role while BGM
  remains visually distinct.
- Issue #449 Previous Item remains out of scope for v0.6.0; adding that command
  stays a backlog item after this release.
- Final phone UI smoke after #448 / #450 is recorded in
  `docs/qa/phone-lan-remote-hardware-results-v0.6.0.md`.
- Long-press and server confirmation for Fade To Black and Panic.
- Setup diagnostics for same-Wi-Fi, dedicated router, Mac hotspot, public Wi-Fi
  AP isolation, missing local network address, port failure, and network
  changes.

The allowed remote actions are Take Next, current media play/pause, return
current media to start, BGM play/pause, BGM previous, BGM next, speaker mode,
Fade To Black, and Panic.

## Release Stack Boundaries

| Item | State |
| --- | --- |
| #448 action-specific command feedback | Closed by PR #451 |
| #450 media/BGM color grouping | Closed by PR #452 |
| Final phone UI smoke after #448 / #450 | Recorded as operator-reported iPhone Safari PASS |
| #449 guarded previous item command | Deferred to backlog |
| PR #454 ImageGen / top chrome UI exploration | Excluded from v0.6.0 |
| Android Chrome | Unverified |

## Reliability And Privacy

The release keeps the remote HTTP layer outside direct ViewModel mutation.
Remote command execution remains routed through existing app action boundaries.
Support reports, diagnostics, and logs must not include token values, nonce
values, controller client IDs, phone addresses, local file paths, raw media
filenames, screenshots, program titles, BGM titles, overlay text, or customer
content.

Hardware rehearsal evidence is recorded in
[`phone-lan-remote-hardware-results-v0.6.0.md`](phone-lan-remote-hardware-results-v0.6.0.md).
The recorded iPhone, router/hotspot, AP-isolation, token-rotation, external
output blackout, final phone UI smoke, and 60-minute soak gates are accepted.
Android Chrome remains unverified for this closeout.

## Install

Download `LiveSwitcher-macOS-v0.6.0.zip` and
`LiveSwitcher-macOS-v0.6.0.zip.sha256` from the GitHub Release, then verify with
`shasum -a 256 -c LiveSwitcher-macOS-v0.6.0.zip.sha256`. Unzip the app and move
`LiveSwitcher.app` to `/Applications`.

## Requirements And Permissions

LiveSwitcher requires macOS 14 or later and has been tested on Apple Silicon.
Accessibility permission is required for PPT EventTap/page-clicker interception.
Apple Events permission is required for Keynote and WPS automation. Microphone
access is reserved for audio-monitoring workflows.

## Release Trust

The public build is source-available, ad-hoc signed, and not notarized. The
Release workflow read `VERSION`, required the tag version to match `VERSION`,
required the tag commit to equal `origin/main`, ran the release gates, packaged
with `ditto`, verified the extracted app, and uploaded both the zip and
checksum assets. The GitHub Release is published at
https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0.

The v0.6.0 release trust model remains tag/main equality plus CI workflow
evidence, release asset checksum verification, and extracted app verification.
It does not promise byte-for-byte local rebuild reproducibility.

## Prohibited Actions

- PR #454 is explicitly excluded from v0.6.0.
- Issue #449 remains backlog and is not part of the v0.6.0 release candidate.
- Do not merge PR #454 into v0.6.0.
- Do not rebase PR #454 into the release stack.
- Do not include PR #454 in v0.6.0 release notes, artifact audit, approval
  package, or release candidate source.
- Do not add #449 Previous Item behavior to v0.6.0.
- Do not add new phone remote commands, arbitrary source switching, remote
  projection toggles, remote editing, or remote configuration.
- Do not mutate the v0.6.0 tag, GitHub Release, release asset, or checksum
  after publication without a new explicit release-maintenance approval.

## Readiness Boundary

The release-readiness, artifact-audit, final-approval, and publication-audit
records are now historical evidence for the completed v0.6.0 release. The
published release target is `1498da8d11777cd4e52ce0740dc52d47ca602bb3`.

For automated release-readiness checks: the release is now complete; do not
create or mutate tags or release assets from readiness PRs.

## Current Release Gate

v0.6.0 is released-complete. No release action is required.

## Candidate Artifact Audit

Local candidate artifact evidence is recorded in
[`release-artifact-audit-v0.6.0.md`](release-artifact-audit-v0.6.0.md). The
audit covers app launch verification, the v0.6.0 app bundle metadata,
`build_v33.sh`, Info.plist linting, ad-hoc code signature verification, app
binary hash, max-depth-3 app file-list hash, AppIcon hash, zip hash, and
checksum verification.

The local candidate audit remains historical pre-publication evidence. The
published release asset is recorded separately in
[`release-publication-audit-v0.6.0.md`](release-publication-audit-v0.6.0.md).

## Final Approval Package

The maintainer-facing approval summary is recorded in
[`release-approval-package-v0.6.0.md`](release-approval-package-v0.6.0.md).
It lists the current release notes, hardware evidence, final phone UI smoke,
candidate source SHA, artifact audit SHA, published release hash evidence,
known limitations, Android Chrome unverified status, Issue #449 deferral, and
PR #454 exclusion. The publication state is recorded in
[`release-publication-audit-v0.6.0.md`](release-publication-audit-v0.6.0.md).

## Known Limitations

- The public build is not Apple-notarized.
- Phone remote control is LAN-only and depends on local network routing.
- Public Wi-Fi with AP isolation is expected to fail gracefully.
- Android Chrome hardware coverage remains unverified.
- Keynote/WPS behavior depends on installed app versions and macOS permissions.
