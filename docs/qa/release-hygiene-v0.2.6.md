# LiveSwitcher v0.2.6 Release Hygiene Checklist

This checklist is for the public release path. It complements the app-level live QA guides and focuses on repository, documentation, CI, and release asset hygiene.

本清单用于公开发布流程。它补充 App 内现场 QA 文档，重点检查仓库、文档、CI 和发布资产卫生。

## Before Push

1. Confirm the target repo is `91wan/LiveSwitcher` and the working branch is not `main`.
2. Run:

```bash
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
cd ../..
git diff --check
./script/check_release_hygiene.sh
```

3. Confirm README links are split:
   - `README.md` is English-first and links to `README_ZH.md`.
   - `README_ZH.md` is Chinese-first and links back to `README.md`.
4. Confirm screenshots use neutral demo data and contain no real customer, city, activity, or local machine path.

## 推送前

1. 确认目标仓库是 `91wan/LiveSwitcher`，当前分支不是 `main`。
2. 执行：

```bash
swift build
swift test
cd Sources/AnnualMeetingSwitcher && swift test
cd ../..
git diff --check
./script/check_release_hygiene.sh
```

3. 确认 README 已拆分：
   - `README.md` 以英文为主，并链接到 `README_ZH.md`。
   - `README_ZH.md` 以中文为主，并链接回 `README.md`。
4. 确认截图使用中性演示数据，不含真实客户、城市、活动名或本机路径。

## Before Tagging

1. Merge the PR only after GitHub Smoke Tests pass.
2. Pull the latest `main`.
3. Run `./script/check_release_hygiene.sh` again on `main`.
4. Build the release app:

```bash
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"
codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"
```

5. Tag only after the local release app verifies.

## 打 Tag 前

1. 只有 GitHub Smoke Tests 通过后才合并 PR。
2. 拉取最新 `main`。
3. 在 `main` 上重新执行 `./script/check_release_hygiene.sh`。
4. 构建发布 App：

```bash
bash Sources/AnnualMeetingSwitcher/build_v33.sh
plutil -lint "$HOME/Downloads/LiveSwitcher.app/Contents/Info.plist"
codesign --verify --deep --strict "$HOME/Downloads/LiveSwitcher.app"
```

5. 只有本地发布 App 验证通过后才打 tag。

## Acceptance

- `README.md` and `README_ZH.md` are both present and cross-linked.
- Current release references point to `v0.2.6`.
- Privacy and local-path scans pass.
- GitHub Smoke Tests include build, test, diff check, and release hygiene.
- Release asset name is `LiveSwitcher-macOS-v0.2.6.zip`.

## 验收标准

- `README.md` 和 `README_ZH.md` 都存在，并互相链接。
- 当前发布引用指向 `v0.2.6`。
- 隐私和本机路径扫描通过。
- GitHub Smoke Tests 覆盖 build、test、diff check 和 release hygiene。
- 发布资产名称为 `LiveSwitcher-macOS-v0.2.6.zip`。
