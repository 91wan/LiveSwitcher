# LiveSwitcher v0.2.9 Release Hygiene Checklist

Use this checklist before pushing, tagging, or publishing `v0.2.9`.

发布 `v0.2.9` 前使用本清单。

## Version Surface

- `AppConfiguration.appVersion` is `0.2.9`.
- `script/build_and_run.sh` uses marketing version `0.2.9`.
- `Sources/AnnualMeetingSwitcher/build_v33.sh` writes `CFBundleShortVersionString` as `0.2.9`.
- README links point to `LiveSwitcher-macOS-v0.2.9.zip`.
- `docs/qa/live-support-report-hardening-v0.2.9.md` exists.

## 版本表面

- `AppConfiguration.appVersion` 为 `0.2.9`。
- `script/build_and_run.sh` 使用 marketing version `0.2.9`。
- `Sources/AnnualMeetingSwitcher/build_v33.sh` 写入 `CFBundleShortVersionString` 为 `0.2.9`。
- README 发布资产引用指向 `LiveSwitcher-macOS-v0.2.9.zip`。
- `docs/qa/live-support-report-hardening-v0.2.9.md` 已存在。

## Required Local Gates

```bash
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

## 必须本地通过

```bash
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

## Release Gates

- GitHub Smoke Tests pass on the PR and on `main`.
- Tag `v0.2.9` triggers Release workflow successfully.
- Release asset is named `LiveSwitcher-macOS-v0.2.9.zip`.
- Downloaded release app reports `CFBundleShortVersionString` as `0.2.9`.
- Downloaded release asset passes plist, codesign, SHA-256, and ShipGate checks.

## 发布门禁

- GitHub Smoke Tests 在 PR 和 `main` 上均通过。
- tag `v0.2.9` 成功触发 Release workflow。
- Release asset 名称为 `LiveSwitcher-macOS-v0.2.9.zip`。
- 下载后的 App `CFBundleShortVersionString` 为 `0.2.9`。
- 下载后的发布资产通过 plist、codesign、SHA-256 和 ShipGate 检查。
