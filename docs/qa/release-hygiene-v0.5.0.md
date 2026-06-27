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

## Release integrity audit - 2026-06-27

This audit verifies the published `v0.5.0` release without changing production code.

| Item | Result |
|---|---|
| `origin/main` | `c0e6a046ad4b1892a158e76d5931dd90bb4b8549` |
| `v0.5.0^{commit}` | `c0e6a046ad4b1892a158e76d5931dd90bb4b8549` |
| Tag/main equality | PASS |
| `VERSION` | `0.5.0` |
| GitHub Release | Present |
| Release URL | https://github.com/91wan/LiveSwitcher/releases/tag/v0.5.0 |
| Draft | `false` |
| Prerelease | `false` |
| Published at | `2026-06-26T09:21:08Z` |
| Release workflow run | `28228782033`, success |
| Release job | `83627124387`, success |
| Production code changes in this audit | None |

Release workflow `28228782033` ran from `v0.5.0` at `c0e6a046ad4b1892a158e76d5931dd90bb4b8549`. The `Build macOS App Release` job completed successfully, including `Read Version`, `Verify Tag Points At Origin Main`, `Test`, `Workspace Guard`, `Release Hygiene`, `Package App Bundle`, and `Create GitHub Release`.

### Assets

| Asset | Size | Digest / checksum |
|---|---:|---|
| `LiveSwitcher-macOS-v0.5.0.zip` | `4806149` | GitHub asset digest `sha256:6df57e42c095030853c325606a2594d01ba925ce6a50badd5ffe57361d3bbf91`; downloaded checksum PASS |
| `LiveSwitcher-macOS-v0.5.0.zip.sha256` | `96` | GitHub asset digest `sha256:4d7da61db7b21ed9b7d0d80ce040a8c9106b8602ad965d4f37d73a6d6c22302c` |

Downloaded release asset verification:

```text
LiveSwitcher-macOS-v0.5.0.zip: OK
extracted/LiveSwitcher.app/Contents/Info.plist: OK
CFBundleIdentifier = com.91wan.liveswitcher
CFBundleShortVersionString = 0.5.0
LSMinimumSystemVersion = 14.0
codesign --verify --deep --strict extracted/LiveSwitcher.app: PASS
```

### Local gate evidence

| Gate | Result |
|---|---|
| `swift build` | PASS |
| `swift test` | PASS, 3820 tests, 0 failures |
| `swift test --package-path Sources/AnnualMeetingSwitcher` | PASS, 3820 tests, 0 failures |
| `git diff --check` | PASS |
| `./script/check_workspace_guard.sh --dev` | PASS |
| `./script/test_workspace_guard.sh` | PASS |
| `./script/check_release_hygiene.sh` | PASS |
| `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh` | PASS |
| `bash Sources/AnnualMeetingSwitcher/build_v33.sh` | PASS |
| `plutil -lint dist/LiveSwitcher.app/Contents/Info.plist` | PASS |
| `codesign --verify --deep --strict dist/LiveSwitcher.app` | PASS |

Local build metadata:

```text
CFBundleIdentifier = com.91wan.liveswitcher
CFBundleShortVersionString = 0.5.0
LSMinimumSystemVersion = 14.0
local executable sha256 = 60a79df46c3c6363e6c0745d224418e06edd62e036b1430d8a9b47b427d24027
release executable sha256 = 13db7ead54897207b873cbd70a5b1f1d563a32c213f70c8b97a001b7afb0e4fd
```

The local rebuild executable hash does not match the downloaded release executable hash. This audit does not treat that as a release blocker because the release workflow built and uploaded from the verified `v0.5.0` tag commit, the tag commit equals `origin/main`, the release workflow passed, the downloaded zip checksum matches the published checksum, and the extracted release app passes metadata and signature verification. The current release process is trusted by CI gate evidence and asset checksum verification, not by byte-for-byte local rebuild reproducibility.

### README screenshot and hygiene

`README.md` and `README_ZH.md` both use the dynamic release badge and reference only `docs/assets/readme/live-console-v0.5.0.png` for the public README screenshot. The old README screenshot slots are not referenced from the front page.

Conclusion: `v0.5.0` is published with the expected assets and verified checksum. No tag, release, asset, production-code, dependency, bundle identifier, macOS minimum-version, or republish action is required by this audit.

## Known limitations

- The public build is not Apple-notarized.
- Keynote/WPS behavior depends on installed app versions and macOS permissions.
- Hardware-specific projection and audible Panic behavior require the canonical RC rehearsal.
