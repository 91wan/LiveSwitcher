# LiveSwitcher v0.2.8 Release Hygiene Checklist

Use this checklist before pushing, tagging, or publishing `v0.2.8`.

发布 `v0.2.8` 前使用本清单。

## Public Content Gate

- README links point to `LiveSwitcher-macOS-v0.2.8.zip`.
- README and README_ZH describe `Copy Support` and `Save Support...`.
- `docs/qa/live-support-report-v0.2.8.md` exists.
- Support reports do not expose screenshots, system logs, local paths, `file://` URLs, raw media filenames, media titles, overlay text, or customer text.

## 公开内容门禁

- README 发布资产引用指向 `LiveSwitcher-macOS-v0.2.8.zip`。
- README 和 README_ZH 说明 `Copy Support` 和 `Save Support...`。
- `docs/qa/live-support-report-v0.2.8.md` 已存在。
- 支持报告不暴露截图、系统日志、本机路径、`file://` URL、原始媒体文件名、媒体标题、叠层文字或客户文案。

## Local Verification

- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"`
- `codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"`

## 本地验证

- `swift build`
- `swift test`
- `cd Sources/AnnualMeetingSwitcher && swift test`
- `git diff --check`
- `./script/check_release_hygiene.sh`
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`
- `./script/build_and_run.sh --verify`
- `bash Sources/AnnualMeetingSwitcher/build_v33.sh`
- `plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"`
- `codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"`

## GitHub Release Gate

- GitHub Smoke Tests pass on the PR.
- Tag `v0.2.8` triggers Release workflow successfully.
- Release asset is named `LiveSwitcher-macOS-v0.2.8.zip`.
- Downloaded release app reports `CFBundleShortVersionString` as `0.2.8`.
- Downloaded release app passes `codesign --verify --deep --strict`.

## GitHub 发布门禁

- PR 的 GitHub Smoke Tests 通过。
- tag `v0.2.8` 成功触发 Release workflow。
- Release asset 名称为 `LiveSwitcher-macOS-v0.2.8.zip`。
- 下载后的 App `CFBundleShortVersionString` 为 `0.2.8`。
- 下载后的 App 通过 `codesign --verify --deep --strict`。
