# LiveSwitcher v0.6.0 Artifact Audit

This document records the local release-candidate artifact audit for the
v0.6.0 release stream. It is evidence only. It does not create a tag, publish a
GitHub Release, or upload release assets.

## Scope

- Repository: `91wan/LiveSwitcher`
- Candidate source SHA: `faf664680800171cf48181063a4510a5e119b06e`
- Candidate source PR: `#446` (`codex/v0-6-0-release-readiness`)
- Audit branch: `release/v0.6.0-artifact-audit`
- Target version: `0.6.0`
- `VERSION` file value: `0.6.0`
- Artifact upload: not performed
- Tag created: no
- GitHub Release created: no
- Prior artifact hashes from source `6e0adf68b80b19adae3ef56020b07c100f4088e0`
  are superseded and must not be reused.

## Bundle Metadata

`dist/LiveSwitcher.app/Contents/Info.plist` was linted successfully.

Required fields:

| Field | Value |
| --- | --- |
| `CFBundleIconFile` | `AppIcon` |
| `CFBundleIdentifier` | `com.91wan.liveswitcher` |
| `CFBundleName` | `LiveSwitcher` |
| `CFBundleShortVersionString` | `0.6.0` |
| `LSMinimumSystemVersion` | `14.0` |

The bundle identifier, bundle name, and minimum macOS version remain unchanged.

## Verification Commands

The following commands were run locally from the artifact-audit worktree:

```bash
./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint dist/LiveSwitcher.app/Contents/Info.plist
codesign --verify --deep --strict dist/LiveSwitcher.app
plutil -p dist/LiveSwitcher.app/Contents/Info.plist | grep -E 'CFBundleShortVersionString|CFBundleIdentifier|LSMinimumSystemVersion|CFBundleName|CFBundleIconFile'
shasum -a 256 dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher
find dist/LiveSwitcher.app -maxdepth 3 -type f | sort | shasum -a 256
shasum -a 256 dist/LiveSwitcher.app/Contents/Resources/AppIcon.icns
ditto -c -k --keepParent dist/LiveSwitcher.app dist/LiveSwitcher-macOS-v0.6.0.zip
shasum -a 256 dist/LiveSwitcher-macOS-v0.6.0.zip > dist/LiveSwitcher-macOS-v0.6.0.zip.sha256
shasum -a 256 -c dist/LiveSwitcher-macOS-v0.6.0.zip.sha256
```

Results:

| Gate | Result |
| --- | --- |
| App launch verification | PASS |
| `build_v33.sh` release bundle build | PASS |
| Info.plist lint | PASS |
| Code signature verification | PASS |
| Zip checksum verification | PASS |

App launch verification was performed through `./script/build_and_run.sh
--verify` before the final `build_v33.sh` bundle rebuild. The contract-required
artifact gates are launch, build, metadata, signature, zip, and checksum
verification.

## Hash Evidence

| Artifact | SHA-256 |
| --- | --- |
| `dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher` | `f374be32fc7bddb7cb144350905192d179b376f05c17f6d6b825492bc54d3561` |
| `dist/LiveSwitcher.app` max-depth-3 file-list hash | `f84e3ef6556deed510f036548919421596ea5ed2e343d892422116a58532c1ec` |
| `dist/LiveSwitcher.app/Contents/Resources/AppIcon.icns` | `8701619d0a3ce827cd6e3a200ab660aff6d87ff273d2a15ee60ec72e62099c06` |
| `dist/LiveSwitcher-macOS-v0.6.0.zip` | `cf617288dd0e34bd753dfaa2c5f997f8756668c41b71de9a5e919aee1a98fbbb` |

Zip size: `4,229,812` bytes.

## Bundle Contents

The max-depth-3 bundle audit contains only the expected app executable,
Info.plist, app icon, and code signature resources within the checked depth:

```text
dist/LiveSwitcher.app/Contents/Info.plist
dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher
dist/LiveSwitcher.app/Contents/Resources/AppIcon.icns
dist/LiveSwitcher.app/Contents/_CodeSignature/CodeResources
```

## Data Boundary Check

Static artifact inspection found no token values, command nonces, controller
client id values, phone IP literals, program titles, BGM titles, customer names,
or runtime support-report data in the candidate app bundle. Expected static
code strings remain present, including BGM UI labels, remote command error
codes, and the `X-Remote-Client-ID` header name; these are not customer/runtime
data. The local zip was not uploaded as a release asset.

The focused static scan for `token=`, `192.168.`, and live program-title samples
returned no matches. A broader scan surfaced the app's built-in privacy notice
phrase `customer content`, which is expected static help text and not customer
data. No token values, phone IP literals, or live program-title samples were found.

Final publication must still use the GitHub Release workflow so the public zip
and checksum are generated from the approved tag on GitHub infrastructure.

## Decision

The local v0.6.0 candidate app bundle passes the artifact integrity audit. This
does not approve publication. The release remains blocked on the final approval
package and explicit user authorization before any tag or GitHub Release action.
