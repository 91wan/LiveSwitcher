# LiveSwitcher v0.5.0 Release Acceptance

## Static evidence

This document freezes the v0.5.0 release acceptance evidence. It is not a reusable release-candidate template. Future rehearsals should use [`release-candidate-rehearsal.md`](release-candidate-rehearsal.md) and keep candidate-specific results outside the template.

## Release Identity

| Item | Evidence |
|---|---|
| Version | `0.5.0` |
| Tag commit | `c0e6a046ad4b1892a158e76d5931dd90bb4b8549` |
| `origin/main` at release audit | `c0e6a046ad4b1892a158e76d5931dd90bb4b8549` |
| Release URL | https://github.com/91wan/LiveSwitcher/releases/tag/v0.5.0 |
| Published at | `2026-06-26T09:21:08Z` |
| Release workflow run | `28228782033`, success |
| Release job | `83627124387`, success |

## Published Assets

| Asset | Evidence |
|---|---|
| `LiveSwitcher-macOS-v0.5.0.zip` | GitHub asset digest `sha256:6df57e42c095030853c325606a2594d01ba925ce6a50badd5ffe57361d3bbf91`; downloaded checksum PASS |
| `LiveSwitcher-macOS-v0.5.0.zip.sha256` | GitHub asset digest `sha256:4d7da61db7b21ed9b7d0d80ce040a8c9106b8602ad965d4f37d73a6d6c22302c` |

Downloaded release asset verification:

```text
LiveSwitcher-macOS-v0.5.0.zip: OK
extracted/LiveSwitcher.app/Contents/Info.plist: OK
CFBundleIdentifier = com.91wan.liveswitcher
CFBundleShortVersionString = 0.5.0
LSMinimumSystemVersion = 14.0
codesign --verify --deep --strict extracted/LiveSwitcher.app: PASS
```

## Automated Gates

The release workflow ran from `v0.5.0` at `c0e6a046ad4b1892a158e76d5931dd90bb4b8549` and completed `Build macOS App Release`, including version read, tag/main verification, tests, workspace guard, release hygiene, package creation, app verification, and GitHub Release asset upload.

Local release audit evidence from `docs/qa/release-hygiene-v0.5.0.md`:

| Gate | Evidence |
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

## Operator Acceptance

Operator acceptance recorded in the Codex thread:

- PR #359 stable final app was manually accepted.
- A 60-minute soak was completed and recorded as PASS.
- v0.5.0 release publishing was approved after README screenshot and release badge cleanup.

The static release hygiene audit remains the canonical in-repository asset, checksum, workflow, and metadata evidence for v0.5.0.

## Known Limitations

- The public build is not Apple-notarized.
- Keynote/WPS behavior depends on installed app versions and macOS permissions.
- Hardware-specific projection and audible Panic behavior require release-candidate rehearsal execution for future candidates.
