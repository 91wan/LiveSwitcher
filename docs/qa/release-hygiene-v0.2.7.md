# LiveSwitcher v0.2.7 Release Hygiene Checklist

Use this checklist before pushing, tagging, or publishing `v0.2.7`.

发布 `v0.2.7` 前使用本清单。

## Required Local Gates

```bash
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
git diff --check
./script/check_release_hygiene.sh
./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"
codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"
```

## 必跑本地门禁

```bash
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
git diff --check
./script/check_release_hygiene.sh
./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"
codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"
```

## Public Hygiene

- README remains split into `README.md` and `README_ZH.md`.
- Current release asset references point to `LiveSwitcher-macOS-v0.2.7.zip`.
- Diagnostics docs exist at `docs/qa/live-diagnostics-v0.2.7.md`.
- No sensitive or customer-specific strings are present in tracked text.
- Diagnostics reports do not expose local paths, `file://` URLs, or raw media filenames.

## 公开卫生

- README 保持拆分为 `README.md` 和 `README_ZH.md`。
- 当前发布资产引用指向 `LiveSwitcher-macOS-v0.2.7.zip`。
- 诊断文档位于 `docs/qa/live-diagnostics-v0.2.7.md`。
- tracked 文本中不含敏感或客户专有字符串。
- 诊断报告不暴露本机路径、`file://` URL 或原始媒体文件名。

## GitHub Acceptance

- PR Smoke Tests pass.
- `main` Smoke Tests pass after merge.
- Tag `v0.2.7` triggers Release workflow successfully.
- Release asset is named `LiveSwitcher-macOS-v0.2.7.zip`.
- Downloaded release asset passes `plutil`, `codesign`, and ShipGate asset verification.

## GitHub 验收

- PR Smoke Tests 通过。
- 合并后 `main` Smoke Tests 通过。
- tag `v0.2.7` 成功触发 Release workflow。
- Release asset 名称为 `LiveSwitcher-macOS-v0.2.7.zip`。
- 下载后的发布资产通过 `plutil`、`codesign` 和 ShipGate asset 验证。
