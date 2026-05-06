<div align="center">

# LiveSwitcher

**A native macOS live-event switching console for small stages, meetups, presentations, and event rooms.**

[![Release](https://img.shields.io/github/v/release/91wan/LiveSwitcher?label=release&color=0A84FF)](https://github.com/91wan/LiveSwitcher/releases)
![macOS](https://img.shields.io/badge/macOS-14%2B-444444)
![SwiftPM](https://img.shields.io/badge/build-SwiftPM-FA7343)
![Apple Silicon](https://img.shields.io/badge/tested-Apple%20Silicon-111111)
![No License](https://img.shields.io/badge/license-no%20license-lightgrey)

English | [中文](README_ZH.md) | [Install](#install) | [FAQ](#faq)

</div>

---

## Screenshots

| Preview / Switching | Audio Mixer | Overlays / Subtitles |
| --- | --- | --- |
| ![Preview and switching](docs/assets/readme/preview-switch.png) | ![Audio mixer](docs/assets/readme/audio-mixer.png) | ![Overlays and subtitles](docs/assets/readme/overlays.png) |

## What It Does

LiveSwitcher combines the tools usually spread across a playlist, a presentation app, a music player, and a display switcher into one focused macOS app.

- Build a program queue from video, audio, Keynote, PPTX, and local HTML files.
- Switch content to an external display with wallpaper fallback.
- Keep background music ready with master, media, and BGM volume control.
- Use emergency blackout for stage-safe cut-to-black and mute.
- Add practical overlays: lower third, countdown, and scrolling ticker.
- Use PPT/page-clicker interception when presentation control needs to stay routed to the show app.

## Install

Download the latest release zip from [Releases](https://github.com/91wan/LiveSwitcher/releases), unzip it, and move `LiveSwitcher.app` to `/Applications`.

Current release asset:

```text
LiveSwitcher-macOS-v0.3.4.zip
```

Important: the public build is ad-hoc signed and **not notarized**. On first launch, macOS Gatekeeper may block it. Open **System Settings -> Privacy & Security -> Open Anyway**, or build from source locally.

## Permissions

LiveSwitcher can run without special permissions for basic playlist and monitor work. Some workflows need macOS permissions:

| Permission | Why it is needed |
| --- | --- |
| Accessibility | Required for PPT/page-clicker interception. |
| Apple Events | Required when controlling Keynote or compatible presentation apps. |
| Microphone | Reserved for audio-monitoring workflows. |

## What's New in v0.3.4

- Overlay preflight now reports which sanitized overlay types are active: countdown, ticker, and lower third.
- Countdown state is easier to verify: countdown expiry uses a testable tick path and common run-loop timer scheduling.
- Diagnostics and Support Report include overlay type/remaining-time detail without exposing overlay text or customer content.

See [`docs/qa/live-overlay-reliability-v0.3.4.md`](docs/qa/live-overlay-reliability-v0.3.4.md) for the overlay reliability check.

## Live Preflight

Open the `?` button, switch from `Help` to `Preflight`, and review the live state before projection. The panel reads current runtime state, including external display availability, projection state, current program, BGM readiness/takeover, speaker mode, panic blackout, PPT mode, overlays, wallpaper fallback, auto-next video, and effective media/BGM volume.

Use `Needs attention` before a show. It filters the live checklist to only failed and warning rows, while `All checks` remains available for a full audit. `Copy Report` always copies the complete report, not the filtered view.

For a larger operator view, click `Open Cockpit` or use the macOS `现场控制 -> 打开现场安全台` command. The Safety Cockpit keeps the main console unchanged while showing readiness, top risks, safe actions, sanitized recent events, and support export controls in a separate window.

Use `Copy Support` or `Save Support...` when reporting a bug. Support reports are text-only and sanitized: they include runtime diagnostics, full preflight, and recent event kinds, but not local file paths, raw media filenames, file URLs, screenshots, system logs, overlay text, or customer content.

Related guides:

- [`docs/qa/live-overlay-reliability-v0.3.4.md`](docs/qa/live-overlay-reliability-v0.3.4.md)
- [`docs/qa/release-hygiene-v0.3.4.md`](docs/qa/release-hygiene-v0.3.4.md)
- [`docs/qa/live-safety-events-v0.3.3.md`](docs/qa/live-safety-events-v0.3.3.md)
- [`docs/qa/release-hygiene-v0.3.3.md`](docs/qa/release-hygiene-v0.3.3.md)
- [`docs/qa/live-action-guidance-v0.3.2.md`](docs/qa/live-action-guidance-v0.3.2.md)
- [`docs/qa/release-hygiene-v0.3.2.md`](docs/qa/release-hygiene-v0.3.2.md)
- [`docs/qa/live-safety-cockpit-v0.3.1.md`](docs/qa/live-safety-cockpit-v0.3.1.md)
- [`docs/qa/release-hygiene-v0.3.1.md`](docs/qa/release-hygiene-v0.3.1.md)
- [`docs/qa/live-safety-cockpit-v0.3.0.md`](docs/qa/live-safety-cockpit-v0.3.0.md)
- [`docs/qa/release-hygiene-v0.3.0.md`](docs/qa/release-hygiene-v0.3.0.md)
- [`docs/qa/live-support-report-hardening-v0.2.9.md`](docs/qa/live-support-report-hardening-v0.2.9.md)
- [`docs/qa/release-hygiene-v0.2.9.md`](docs/qa/release-hygiene-v0.2.9.md)
- [`docs/qa/live-support-report-v0.2.8.md`](docs/qa/live-support-report-v0.2.8.md)
- [`docs/qa/live-diagnostics-v0.2.7.md`](docs/qa/live-diagnostics-v0.2.7.md)
- [`docs/qa/live-preflight-focus-v0.2.5.md`](docs/qa/live-preflight-focus-v0.2.5.md)
- [`docs/qa/live-preflight-summary-v0.2.4.md`](docs/qa/live-preflight-summary-v0.2.4.md)
- [`docs/qa/live-preflight-actions-v0.2.3.md`](docs/qa/live-preflight-actions-v0.2.3.md)
- [`docs/qa/live-preflight-v0.2.2.md`](docs/qa/live-preflight-v0.2.2.md)
- [`docs/qa/live-regression-v0.2.1.md`](docs/qa/live-regression-v0.2.1.md)

## v0.2 Live Safety Baseline

- Projection fails closed when no external display is available, and stops projection if the external display is disconnected.
- Speaker mode ducks both media/video audio and BGM to keep live speech clear.
- Playing BGM temporarily fades media audio down and fades BGM in without changing the saved audio strategy.
- The wallpaper tray accepts real Finder image drops and filters non-image files.
- Video can optionally auto-advance only to the immediately next video item; it never auto-opens HTML, PPTX, or Keynote.
- Speaker mode, panic blackout, and PPT mode are available from the macOS menu with keyboard shortcuts.

## Build, Test, Run

```bash
git clone https://github.com/91wan/LiveSwitcher.git
cd LiveSwitcher

swift build
swift test
./script/build_and_run.sh --verify
```

Daily shortcuts:

```bash
make build
make run
make test
bash Sources/AnnualMeetingSwitcher/build_v33.sh
./script/check_release_hygiene.sh
```

`./script/build_and_run.sh --verify` builds `dist/LiveSwitcher.app`, launches it, and verifies that the app process remains running.

## UI Verification

This repository keeps real UI verification screenshots under:

```text
docs/assets/ui-matrix/2026-05-03/
docs/assets/ui-matrix/2026-05-04/
docs/assets/ui-matrix/2026-05-04-v021/
```

The matrix covers three window sizes (`1360x760`, `1440x800`, maximized) across three tabs: preview/switching, audio mixer, and overlays/subtitles.

## Repository Shape

```text
.
├── Package.swift
├── Makefile
├── README.md
├── README_ZH.md
├── docs/assets/
├── script/
├── Sources/AnnualMeetingSwitcher/
└── .github/workflows/
```

## FAQ

### Is LiveSwitcher notarized?

No. The public release is ad-hoc signed but not notarized. Expect Gatekeeper to require manual approval on first launch.

### Does it support Windows or Linux?

No. LiveSwitcher is a native macOS SwiftUI app.

### Can I use it without a second display?

Yes. You can prepare playlists, music, wallpapers, and overlays on a single Mac. External display output is only required for live projection workflows.

### Why are Keynote/PPT permissions required?

Presentation control relies on macOS automation and accessibility APIs. macOS requires explicit user permission for those actions.

## No License

No open-source license is provided. The code is publicly visible, but all rights are reserved by the repository owner unless a license is added later.
