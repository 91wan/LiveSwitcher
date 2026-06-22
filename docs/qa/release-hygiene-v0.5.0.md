# LiveSwitcher v0.5.0

## Highlights

v0.5.0 freezes the current runtime ownership architecture for public release preparation. Runtime-owned snapshots now cover live audio, BGM, projection, PPT, preferences, program state, queue storage, activation planning, automation, support, and presentation query paths.

## Reliability

The release keeps the canonical [Release Candidate rehearsal](release-candidate-rehearsal.md) as the hardware and operator gate. Panic transitions, media playback callbacks, transport source handling, BGM reconciliation, and facade synchronization have focused hardening coverage before public tagging.

## Operator workflow

Live operators still use the main console, Preflight, Safety Cockpit, Support Report export, Panic blackout, speaker mode, BGM takeover, projection controls, and PPT/page-clicker interception from the existing UI. Support Report output remains text-only and sanitized: it avoids local file paths, raw media filenames, file URLs, screenshots, system logs, overlay text, and customer content.

## Install

Download `LiveSwitcher-macOS-v0.5.0.zip` and `LiveSwitcher-macOS-v0.5.0.zip.sha256` from the GitHub Release, then verify with `shasum -a 256 -c LiveSwitcher-macOS-v0.5.0.zip.sha256`. Unzip the app and move `LiveSwitcher.app` to `/Applications`.

## Requirements and permissions

LiveSwitcher requires macOS 14 or later and has been tested on Apple Silicon. Accessibility permission is required for PPT EventTap/page-clicker interception. Apple Events permission is required for Keynote and WPS automation. Microphone access is reserved for audio-monitoring workflows.

## Release trust

The public build is source-available, ad-hoc signed, and not notarized. The Release workflow must read `VERSION`, require the tag version to match `VERSION`, require the tag commit to equal `origin/main`, run the release gates, package with `ditto`, verify the extracted app, and upload both the zip and checksum assets as a draft release.

## Known limitations

- The public build is not Apple-notarized.
- Keynote/WPS behavior depends on installed app versions and macOS permissions.
- Hardware-specific projection and audible Panic behavior require the canonical RC rehearsal.
