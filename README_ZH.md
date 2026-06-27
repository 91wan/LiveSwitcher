<div align="center">

# LiveSwitcher

**面向小型舞台、会议、演示和活动空间的原生 macOS 现场播控切换台。**

[![Release](https://img.shields.io/github/v/release/91wan/LiveSwitcher?label=release&color=0A84FF)](https://github.com/91wan/LiveSwitcher/releases)
![macOS](https://img.shields.io/badge/macOS-14%2B-444444)
![SwiftPM](https://img.shields.io/badge/build-SwiftPM-FA7343)
![Apple Silicon](https://img.shields.io/badge/tested-Apple%20Silicon-111111)
![No License](https://img.shields.io/badge/license-no%20license-lightgrey)

[English](README.md) | 中文 | [安装](#安装) | [常见问题](#常见问题)

</div>

---

## 截图

![LiveSwitcher v0.5.0 控制台](docs/assets/readme/live-console-v0.5.0.png)

_当前 v0.5.0 控制台，使用脱敏 demo 数据。_

## 项目说明

LiveSwitcher 把现场常用的节目列表、演示软件、音乐播放器和外接屏切换能力收在一个 macOS App 里，目标是让小型活动现场更稳、更直观。

- 支持把视频、音频、Keynote、PPTX 和本地 HTML 加入节目队列。
- 支持切换到外接屏，并在无节目时回退到待机壁纸。
- 支持背景音乐、主音量、媒体音量和 BGM 音量控制。
- 支持老板键：一键切黑副屏并静音。
- 支持实用叠层：人名条、倒计时、游动字幕。
- 支持 PPT/翻页笔拦截，让演示控制更贴近现场流程。

## 安装

从 [Releases](https://github.com/91wan/LiveSwitcher/releases) 下载最新 zip，解压后把 `LiveSwitcher.app` 拖到 `/Applications`。

当前发布资产：

```text
LiveSwitcher-macOS-v0.5.0.zip
LiveSwitcher-macOS-v0.5.0.zip.sha256
```

打开 App 前可以先校验 checksum：

```bash
shasum -a 256 -c LiveSwitcher-macOS-v0.5.0.zip.sha256
```

注意：当前公开构建是 source-available、ad-hoc 签名，且 **未经过 Apple notarization**。首次启动时 macOS Gatekeeper 可能会拦截。可以到 **系统设置 -> 隐私与安全性 -> 仍要打开** 放行，或从源码本地构建。后续 notarized 版本需要 Apple Developer ID 证书和 notarytool 凭据。

## 权限

LiveSwitcher 的基础播放列表和监看流程不需要特殊权限。部分现场流程需要 macOS 权限：

| 权限 | 用途 |
| --- | --- |
| 辅助功能 | PPT/翻页笔拦截需要此权限。 |
| Apple Events | 控制 Keynote 或兼容演示软件时需要。 |
| 麦克风 | 为音频监听类流程保留。 |

## v0.5.0 更新

- Media 与 BGM 快速切换更可靠，旧播放器回调不会再覆盖当前节目或曲目。
- BGM 曲库删除和重排会立即同步现场播放状态，不再产生幽灵曲目。
- Panic、投射和 PPT 生命周期更严格，覆盖延迟暂停、外屏断开和 EventTap 状态。
- 节目队列、当前节目、激活、持久化和音频路由使用单一权威现场状态。
- Preflight、安全台和脱敏 Support Report 提供更清晰的发布与故障复盘流程。
- 新增统一 RC 演练门禁，覆盖硬件、权限、隐私和长时间播放。

v0.5.0 发布说明和可信门禁见 [`docs/qa/release-hygiene-v0.5.0.md`](docs/qa/release-hygiene-v0.5.0.md)。

English maintainer note: `v0.5.0` freezes the current runtime ownership architecture and tightens release flow around reproducible candidate artifacts and Draft Releases.

## 现场检查

点击顶部 `?` 按钮，从 `Help` 切到 `Preflight`，即可在投射前检查当前运行状态。面板读取真实状态，包括外接屏、投射、当前节目、BGM 准备/BGM 接管、主讲人模式、老板键、PPT 模式、叠层、壁纸回退、自动下一条视频，以及媒体/BGM 实际输出音量。

开演前优先查看 `Needs attention`。它只显示失败和警告项；如需完整审计，可切到 `All checks`。`Copy Report` 始终复制完整报告，不受当前过滤视图影响。

需要更大的现场视图时，点击 `Open Cockpit`，或使用 macOS 菜单 `现场控制 -> 打开现场安全台`。安全台不会改变主控制台结构，只在独立窗口中展示准备状态、最高风险、安全动作、最近脱敏事件和支持报告导出。

提交 bug 或现场复盘时使用 `Copy Support` 或 `Save Support...`。支持报告是纯文本并已脱敏：包含运行诊断、完整现场检查和最近事件类型，但不包含本机路径、原始媒体文件名、file URL、截图、系统日志、叠层文字或客户内容。

相关文档：

当前验收入口：

- [Release Candidate 演练](docs/qa/release-candidate-rehearsal.md)
- [v0.5.0 发布验收记录](docs/qa/release-acceptance-v0.5.0.md)
- [v0.5.0 发布卫生检查](docs/qa/release-hygiene-v0.5.0.md)
- [v0.5.0 工作区门禁](docs/qa/workspace-guard-v0.5.0.md)
- [当前 UI 验证](docs/qa/ui-current-main.md)
- [Runtime ownership](docs/architecture/runtime-ownership.md)
- [Live Mode simplicity rules](docs/architecture/live-mode-simplicity-rules.md)

旧版本 QA 文档仅供历史参考，不是当前发布门禁。

## v0.2 现场安全基线

- 无外接屏时不会投射，外接屏断开时立即停止投射，避免主屏被黑屏窗口覆盖。
- 主讲人模式一键同时压低媒体/视频声道和 BGM，让现场人声更突出。
- 播放 BGM 时临时淡出媒体声、淡入 BGM，不改变用户保存的混音策略。
- “拖入图片”支持 Finder 图片拖入，并拒绝非图片文件。
- 可选择视频播毕后只自动播放紧邻的下一条视频，不自动打开 HTML、PPTX 或 Keynote。
- 主讲人模式、老板键、PPT 模式加入 macOS 菜单和快捷键。

## 构建、测试、运行

```bash
git clone https://github.com/91wan/LiveSwitcher.git
cd LiveSwitcher

swift build
swift test
./script/build_and_run.sh --verify
```

日常命令：

```bash
make build
make run
make test
make guard-dev
make release-check
bash Sources/AnnualMeetingSwitcher/build_v33.sh
./script/check_release_hygiene.sh
```

`./script/build_and_run.sh --verify` 会构建 `dist/LiveSwitcher.app`，启动应用，并确认应用进程能够持续运行。

`make guard-dev` 会在本地验证前拦截脏工作区。`make release-check` 是打 tag 前的维护者门禁，要求 `main` 与 `origin/main` 完全一致。

## UI 验证

本仓库保留真实 UI 复测截图：

```text
docs/assets/ui-matrix/2026-05-03/
docs/assets/ui-matrix/2026-05-04/
docs/assets/ui-matrix/2026-05-04-v021/
```

矩阵覆盖三个窗口尺寸（`1360x760`、`1440x800`、最大化）。旧截图作为回归素材保留；当前信息架构是 Run Desk / 导播台、Live Ops、Audio 页面 / BGM Library、Overlays / Overlay Composer。

## 仓库结构

```text
.
├── Package.swift
├── Makefile
├── README.md
├── README_ZH.md
├── docs/assets/
├── script/
├── Sources/AnnualMeetingSwitcher/
└── .github/workflows/
```

## 常见问题

### LiveSwitcher 经过 notarization 了吗？

没有。当前公开发布版是 ad-hoc 签名，但未 notarized。首次启动时通常需要在系统设置里手动允许。

### 支持 Windows 或 Linux 吗？

不支持。LiveSwitcher 是原生 macOS SwiftUI App。

### 没有第二块屏幕可以使用吗？

可以。单屏也能准备节目列表、音乐、壁纸和叠层。只有现场投屏时才需要外接显示器。

### 为什么 Keynote/PPT 需要权限？

因为演示控制依赖 macOS 自动化和辅助功能 API。macOS 会要求用户明确授权。

## 无许可证

本仓库未提供开源许可证。代码以 source-available 方式公开，便于审查和本地构建；除非未来添加许可证，否则仓库所有者保留全部权利。
