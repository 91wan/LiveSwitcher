# Phone LAN Remote Hardware Results - v0.6.0 PR-6

This file records the PR-6 hardware rehearsal result for the phone LAN remote
stream. It is candidate evidence, not a reusable template, and it does not
approve a release by itself.

No production code changes belong in this closeout slice. No release, tag, or
v0.6.0 publish is allowed from this document alone.

Automated tests are not hardware evidence. A row is PASS only because the
operator reported direct hardware observation during this PR-6 run, not because
unit tests or Computer Use passed.

Do not commit token values, phone IP addresses, raw logs, screenshots, videos,
customer files, real media filenames, program titles, BGM titles, or local file
paths in this record.

## Candidate Metadata

| Field | Value |
| --- | --- |
| Candidate commit | 9c96da717ded254cf308e3a23ef2da8e8565b661 |
| VERSION | 0.5.0 |
| PR slice | PR-6 hardware rehearsal execution |
| App launch source | local PR-6 worktree app bundle |
| Operator acceptance | PASS reported by user on 2026-06-30 15:21 CST |
| Automated evidence boundary | Build/test/Computer Use are support evidence only, not hardware PASS evidence |
| Release boundary | v0.6.0 release readiness remains blocked until the separate PR-7 draft |

## Hardware Matrix

| Scenario | Result |
| --- | --- |
| Dedicated 5GHz router, iPhone Safari connects by QR | PASS |
| Android Chrome connects by QR | BLOCKED |
| Public Wi-Fi with AP isolation fails gracefully | PASS |
| Mac hotspot works | PASS |
| Remote disabled rejects commands | PASS |
| Token rotation invalidates old phone page | PASS |
| Take Next latency acceptable | PASS |
| Media play/pause works | PASS |
| BGM play/pause/prev/next works | PASS |
| Speaker mode works | PASS |
| FTB long-press works, external output black | PASS |
| Panic long-press works, external output black | PASS |
| No accidental single-tap dangerous action | PASS |
| Phone disconnect/reconnect safe | PASS |
| Mac sleep/network change safe | PASS |
| 60-minute soak with phone connected | PASS |

## Evidence Notes

- iPhone Safari QR pairing, command execution, token rotation, and reconnect
  behavior were accepted by direct operator hardware testing.
- External output FTB and Panic blackout were accepted by direct operator
  observation on the external output path.
- Public Wi-Fi AP isolation was accepted as graceful fail behavior by direct
  operator observation.
- The 60-minute soak was accepted by the operator as PASS.
- Android Chrome is BLOCKED because no Android-specific hardware result was
  provided for this PR-6 run; the contract marks Android as optional when
  available.

## Security And Network Limits

- The remote remains LAN-only: no cloud relay, public internet remote, UPnP,
  or port mapping.
- Dangerous actions still require long-press and server confirmation.
- This record intentionally omits token values, phone IP addresses, raw logs,
  screenshots, customer data, program titles, BGM titles, and local paths.

## Release Gate

This PR-6 record satisfies the hardware rehearsal evidence slice, with Android
explicitly blocked as unavailable for this run. v0.6.0 must still go through a
separate draft release-readiness PR and explicit user approval before any tag or
release.
