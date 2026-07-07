# LiveSwitcher v0.6.0 Publication State Audit

This document records the post-publication state for LiveSwitcher v0.6.0. It is
an audit record only: it does not mutate tags, edit GitHub Releases, upload
assets, or change production code.

## Summary

| Check | Result |
| --- | --- |
| Release state | released-complete |
| Publication target SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3` |
| v0.6.0 tag SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3` |
| tag == publication target | PASS |
| Audit PR base SHA | `1498da8d11777cd4e52ce0740dc52d47ca602bb3` |
| Audit PR relation to tag | post-publication docs/tests evidence, not part of the v0.6.0 released artifact |
| Audit PR review-head identity | Use PR #456 metadata for review-head identity |
| VERSION | `0.6.0` |
| GitHub Release publication | GitHub Release is published |
| GitHub Release exists | yes |
| Release draft | no |
| Release prerelease | no |
| Release URL | https://github.com/91wan/LiveSwitcher/releases/tag/v0.6.0 |
| Release workflow | PASS, run `28848790422` |
| User approval evidence | PASS, maintainer approved v0.6.0 publication before tag/release execution |
| Docs stale after publication | repaired by this audit PR |
| Next action | No release action required |

## Release Assets

| Asset | State | Size / Digest |
| --- | --- | --- |
| `LiveSwitcher-macOS-v0.6.0.zip` | uploaded | `4201330` bytes, `sha256:079865e39ccef8fe711e8c8a34a0d0813288aecf19a66394392533182a9e5ad2` |
| `LiveSwitcher-macOS-v0.6.0.zip.sha256` | uploaded | `96` bytes |

Downloaded asset verification:

```text
079865e39ccef8fe711e8c8a34a0d0813288aecf19a66394392533182a9e5ad2  LiveSwitcher-macOS-v0.6.0.zip
LiveSwitcher-macOS-v0.6.0.zip: OK
```

| Check | Result |
| --- | --- |
| Zip checksum verification | PASS |

## Extracted App Verification

| Field | Value |
| --- | --- |
| Info.plist lint | PASS |
| Codesign verification | PASS |
| CFBundleName | `LiveSwitcher` |
| CFBundleIconFile | `AppIcon` |
| CFBundleIdentifier | `com.91wan.liveswitcher` |
| CFBundleShortVersionString | `0.6.0` |
| LSMinimumSystemVersion | `14.0` |
| App binary SHA-256 | `6d4b4e65f4ae6530801f8e12af6a7dcfb9b8365c58145570838b318d400f4b23` |
| AppIcon SHA-256 | `8701619d0a3ce827cd6e3a200ab660aff6d87ff273d2a15ee60ec72e62099c06` |

## Boundary Checks

| Item | State |
| --- | --- |
| PR #454 | open Draft, CI failed, excluded from v0.6.0 |
| Issue #449 | backlog, not included in v0.6.0 |
| Production code changes in this audit | none |
| Tag mutation in this audit | none |
| Release asset mutation in this audit | none |
| v0.5.0 tag/release/assets | untouched |

## Commands

```bash
git fetch origin --tags
git status --short
git rev-parse HEAD
git rev-parse origin/main
cat VERSION
git rev-parse v0.5.0^{commit}
git rev-parse v0.6.0^{commit}

PUBLICATION_TARGET_SHA=1498da8d11777cd4e52ce0740dc52d47ca602bb3
test "$(git rev-parse v0.6.0^{commit})" = "$PUBLICATION_TARGET_SHA"
git merge-base --is-ancestor v0.6.0 HEAD

gh release view v0.6.0 --json tagName,isDraft,isPrerelease,name,url,assets,targetCommitish,createdAt,publishedAt

mkdir -p /tmp/liveswitcher-v060-release-audit
cd /tmp/liveswitcher-v060-release-audit
gh release download v0.6.0 --repo 91wan/LiveSwitcher --pattern 'LiveSwitcher-macOS-v0.6.0.zip*'
shasum -a 256 -c LiveSwitcher-macOS-v0.6.0.zip.sha256
ditto -x -k LiveSwitcher-macOS-v0.6.0.zip extracted
plutil -lint extracted/LiveSwitcher.app/Contents/Info.plist
codesign --verify --deep --strict extracted/LiveSwitcher.app
plutil -p extracted/LiveSwitcher.app/Contents/Info.plist | grep -E 'CFBundleShortVersionString|CFBundleIdentifier|LSMinimumSystemVersion|CFBundleName|CFBundleIconFile'
shasum -a 256 extracted/LiveSwitcher.app/Contents/MacOS/LiveSwitcher
shasum -a 256 extracted/LiveSwitcher.app/Contents/Resources/AppIcon.icns
```

## Decision

v0.6.0 is released-complete. No release action is required. Future work should
remain outside v0.6.0 unless a new post-v0.6 contract explicitly scopes it.
