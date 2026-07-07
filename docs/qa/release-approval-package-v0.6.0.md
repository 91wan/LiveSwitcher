# LiveSwitcher v0.6.0 Final Approval Package

This document records the maintainer-facing approval information for the
v0.6.0 release stream and its final publication result. The release is now
released-complete; this document is evidence only and does not mutate tags,
GitHub Releases, or release assets.

## Approval Target

| Field | Value |
| --- | --- |
| Version | `0.6.0` |
| Release stack | `#446` release readiness -> `#447` artifact audit -> `#453` final approval package |
| Candidate source SHA | `faf664680800171cf48181063a4510a5e119b06e` |
| Artifact audit SHA | `cf8c607e7ee31deeb0016a47106f3ccc6a12b878` |
| Publication target SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3` |
| Release state | released-complete |
| Release publication | GitHub Release is published |
| GitHub Release | https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0 |
| Release draft | `false` |
| Release prerelease | `false` |

The final `v0.6.0` tag and `origin/main` both resolve to
`1498da8d11777cd4e52ce0740dc52d47ca602bb3`.

## Release Notes

v0.6.0 focuses on the local phone LAN remote-control MVP for live operators.
The remote is browser-based, LAN-only, token protected, single-controller by
default, and limited to approved Live Mode execution actions.

Included highlights:

- Phone LAN remote pairing with QR/local URL from the Mac operator surface.
- Single controller ownership; later clients are read-only.
- Hardened command IDs for iPhone Safari on non-secure LAN origins.
- Action-specific command feedback for Issue #448, without leaking sensitive
  values.
- Program/media color role cleanup for Issue #450, while BGM controls remain
  visually distinct.
- Long-press plus server confirmation nonce for Fade To Black and Panic.
- Setup diagnostics for same-Wi-Fi, dedicated router, Mac hotspot, AP
  isolation, missing local network address, port failure, and network changes.
- Refreshed v0.6.0 app icon and README screenshot.

Deferred:

- Issue #449, guarded Previous Item / 切上一项, remains open and is not part of v0.6.0.
- PR #454, ImageGen / top chrome UI exploration, is explicitly excluded from v0.6.0.

## Evidence Links

| Evidence | Status |
| --- | --- |
| Release readiness | PASS, see `docs/qa/release-readiness-v0.6.0.md` |
| Hardware rehearsal | PASS, see `docs/qa/phone-lan-remote-hardware-results-v0.6.0.md` |
| Final phone UI smoke after #448 / #450 | PASS, see [`docs/qa/phone-lan-remote-hardware-results-v0.6.0.md`](phone-lan-remote-hardware-results-v0.6.0.md#final-phone-ui-smoke-after-448--450) |
| Release hygiene | PASS, see `docs/qa/release-hygiene-v0.6.0.md` |
| Candidate artifact audit | PASS, see `docs/qa/release-artifact-audit-v0.6.0.md` |
| Publication state audit | PASS, see `docs/qa/release-publication-audit-v0.6.0.md` |
| Workspace guard | PASS, see `docs/qa/workspace-guard-v0.6.0.md` |
| PR #454 | Explicitly excluded from v0.6.0 |
| Android Chrome | Unverified / unavailable for this run |

## Artifact Summary

| Artifact | SHA-256 |
| --- | --- |
| App binary | `f374be32fc7bddb7cb144350905192d179b376f05c17f6d6b825492bc54d3561` |
| App max-depth-3 file list | `f84e3ef6556deed510f036548919421596ea5ed2e343d892422116a58532c1ec` |
| AppIcon | `8701619d0a3ce827cd6e3a200ab660aff6d87ff273d2a15ee60ec72e62099c06` |
| Published release zip | `079865e39ccef8fe711e8c8a34a0d0813288aecf19a66394392533182a9e5ad2` |

The published release zip was downloaded from GitHub Releases and verified with
`LiveSwitcher-macOS-v0.6.0.zip: OK`.

## Known Limitations

- The public build is source-available, ad-hoc signed, and not notarized.
- Phone remote control is LAN-only and depends on local network routing.
- Public Wi-Fi with AP isolation is expected to fail gracefully.
- Android Chrome hardware coverage was unavailable for this run.
- Keynote/WPS behavior depends on installed app versions and macOS permissions.
- Issue #449 remains deferred and must not be folded into v0.6.0.
- PR #454 remains outside the release stack and must not be folded into v0.6.0.

## Publication Approval

The maintainer explicitly approved publication with `批准发布 v0.6.0` before the
tag and GitHub Release workflow were executed. The final release target is
`1498da8d11777cd4e52ce0740dc52d47ca602bb3`.
