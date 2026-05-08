# LiveSwitcher v0.3.5 Release Hygiene Checklist

Use this checklist before pushing, tagging, or publishing `v0.3.5`.

发布 `v0.3.5` 前使用本清单。

## Version Surface

- `AppConfiguration.appVersion` is `0.3.5`.
- `script/build_and_run.sh` uses marketing version `0.3.5`.
- `Sources/AnnualMeetingSwitcher/build_v33.sh` writes `CFBundleShortVersionString` as `0.3.5`.
- README links point to `LiveSwitcher-macOS-v0.3.5.zip`.
- `docs/qa/workspace-guard-v0.3.5.md` exists.

## Workspace Guard

- `./script/test_workspace_guard.sh` passes.
- `./script/check_workspace_guard.sh --dev` passes before local build/test gates.
- `./script/check_workspace_guard.sh --release` passes only on clean `main` aligned with `origin/main`.
- GitHub Smoke Tests run `./script/check_workspace_guard.sh --dev`.
- GitHub Release workflow runs workspace guard and release hygiene before packaging.

## 中文发布门禁

- 本地工作区必须干净，没有删除、修改或未跟踪文件。
- 打 tag 前必须在 `main`。
- 打 tag 前本地 `main` 必须等于 `origin/main`。
- CI 和 release workflow 必须先跑 workspace guard，再继续构建或打包。

## Required Local Gates

```bash
./script/test_workspace_guard.sh
./script/check_workspace_guard.sh --dev
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
git diff --check
./script/check_release_hygiene.sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh
./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"
codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"
```

## Release Verification

- PR Smoke Tests pass.
- Squash merge lands on `main`.
- Local `main` fast-forwards to `origin/main`.
- `v0.3.5` tag triggers Release workflow successfully.
- Release asset is named `LiveSwitcher-macOS-v0.3.5.zip`.
- Downloaded release app reports `CFBundleShortVersionString` as `0.3.5`.
- Downloaded release app passes `codesign --verify --deep --strict`.
- ShipGate source and release-asset scans pass.
