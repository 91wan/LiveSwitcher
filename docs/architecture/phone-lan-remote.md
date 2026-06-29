# Phone LAN Remote Control Decision

Decision date: 2026-06-28

Status: approved for the v0.6.0 feature stream.

This document approves a phone remote-control direction for LiveSwitcher. It is
an architecture and product-boundary decision only. It does not implement a
server, mobile UI, pairing UI, runtime command bridge, or release.

No v0.5.1 release is triggered by this decision.

## Decision

Use Web + Wi-Fi/LAN for the MVP.

The phone remote is a normal browser page served by LiveSwitcher on the local
network. The phone and Mac must be on the same local network. The MVP does not
require a cloud service, public internet access, account login, WebRTC, UPnP, or
port forwarding.

Bluetooth is rejected for the MVP. Browser-based Bluetooth is not reliable
enough across iOS and Android for this use case, and a reliable Bluetooth path
would push the product toward a native app and a more complex pairing model.

The native iOS app MVP is rejected. The MVP must avoid App Store/TestFlight
distribution, signing, installation, and a second app surface. The target is a
simple local remote, not a second production console.

## Product Boundary

The phone remote is not a second switcher console. It may only invoke a small
set of existing Live Mode execution actions and must not expose setup or edit
surfaces.

It does not add Mac Live Mode controls. Setup, pairing, QR code display,
enable/disable controls, and token lifecycle controls belong outside Live Mode.
Live Mode may show a small read-only connected status later, but remote setup is
not a Live Mode configuration surface.

Allowed MVP action tokens must already exist in
`LiveModeSimplicityPolicy.allowedActions`:

| Remote intent | Existing Live Mode action token |
|---|---|
| Take Next | `takeNext` |
| Current media play/pause | `toggleCurrentMediaPlayback` |
| Current media return to start | `returnCurrentMediaToStart` |
| BGM play/pause | `bgmPlayPause` |
| BGM previous | `bgmPrevious` |
| BGM next | `bgmNext` |
| Speaker mode | `toggleSpeakerMode` |
| Fade to black | `toggleFadeToBlack` |
| Panic | `togglePanic` |

The remote projection toggle is not in the MVP. Projection ownership remains on
the Mac operator surface.

The remote arbitrary source switching is not in the MVP. The first remote
execution path is Take Next, because it preserves the operator-prepared queue
and reduces accidental source selection.

Overlay preset triggering, standby wallpaper selection, PPT mode toggling,
program import, queue editing, BGM library editing, automation editing, release
settings, and debug settings are not part of the phone remote MVP.

## Safety Model

Remote control is off by default. The Mac operator must explicitly enable it for
the current session.

When enabled, LiveSwitcher will later generate a high-entropy session token and
show a local URL/QR code. Closing remote control must invalidate the token and
stop the listener.

Dangerous actions require strong confirmation:

- `toggleFadeToBlack`
- `togglePanic`

The command layer must reject dangerous actions without confirmation and must
guard duplicate command ids. A phone single tap must not trigger these actions.

## Runtime Boundary

The HTTP layer must never mutate app state directly.

Future command execution must go through existing ViewModel/Runtime action
boundaries. If a clean public facade does not exist for an approved command, add
the narrow facade first and keep the server unaware of internal mutable state.

## Privacy And Diagnostics

Support reports, logs, and diagnostics must not include the remote URL token,
full client IP, imported file paths, event text, program names, company names,
guest names, or BGM titles.

Snapshots may include the current and next program titles and current BGM title
only for the phone control UI. These values must not be copied into support
reports or server logs.

## Release Boundary

This decision starts a v0.6.0 feature stream. It does not change VERSION, the
v0.5.0 tag, GitHub Release assets, checksums, Bundle Identifier, app name, or the
minimum macOS version.

Do not publish v0.6.0 until all remote-control feature PRs are merged, hardware
rehearsal passes, the security/privacy checklist passes, and the user explicitly
approves the release.
