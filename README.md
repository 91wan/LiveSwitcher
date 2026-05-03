# LiveSwitcher

LiveSwitcher is a native macOS live-event switching console for small stages,
meetups, presentations, and event rooms. It combines a program playlist,
external-display output, local HTML presentation output, background music
control, emergency blackout, wallpapers, and lightweight overlays in one
SwiftUI app.

LiveSwitcher 是一个原生 macOS 现场播控切换台，适合小型舞台、会议、演示和活动空间使用。它把节目播放列表、外接屏输出、本地 HTML 展示、背景音乐控制、紧急黑屏、壁纸和轻量字幕叠加整合在一个 SwiftUI 应用里。

Version: `v0.1.1`
版本：`v0.1.1`
Platform: macOS 14.0+ on Apple Silicon
平台：macOS 14.0+，Apple Silicon
Distribution: source available, no license granted
分发方式：源码公开可见，但未授予开源许可证

## Features / 功能

- Program playlist for video, audio, Keynote, PPTX, and local HTML files.
- 支持视频、音频、Keynote、PPTX 和本地 HTML 文件的节目播放列表。
- External display output with wallpaper fallback and emergency blackout.
- 支持外接屏输出、壁纸回退和紧急黑屏。
- Program monitor with live/preview-oriented switching state.
- 提供面向导播场景的 Program Monitor 和预监/切换状态。
- Background music playlist, master volume, media volume, and BGM volume.
- 支持背景音乐列表、主音量、媒体音量和 BGM 音量控制。
- Presenter mode to reduce BGM while keeping the program source active.
- 支持主讲人模式，在保留节目源的同时压低 BGM。
- HTML full-screen output through `WKWebView` with local asset access.
- 通过 `WKWebView` 输出本地 HTML 全屏展示，并支持本地资源访问。
- Lower-third, ticker, and countdown overlays.
- 支持姓名条、滚动字幕和倒计时叠加层。
- Page-clicker interception mode for presentation workflows.
- 支持翻页笔拦截模式，适配演示流程。

## Requirements / 系统要求

- macOS 14.0 or later.
- macOS 14.0 或更高版本。
- Apple Silicon Mac.
- Apple Silicon Mac。
- Xcode 15 or Command Line Tools.
- Xcode 15 或 Command Line Tools。
- Accessibility permission for page-clicker interception mode.
- 翻页笔拦截模式需要辅助功能权限。
- Apple Events permission when controlling presentation apps.
- 控制 Keynote 等演示应用时可能需要 Apple Events 权限。

## Build, Test, Run / 构建、测试、运行

```bash
git clone https://github.com/91wan/LiveSwitcher.git
cd LiveSwitcher

swift build
swift test

./script/build_and_run.sh --verify
```

Daily shortcuts / 日常快捷命令：

```bash
make build
make run
make test
bash Sources/AnnualMeetingSwitcher/build_v33.sh
```

`./script/build_and_run.sh --verify` builds `dist/LiveSwitcher.app`, launches it,
and verifies that the app process remains running.

`./script/build_and_run.sh --verify` 会构建 `dist/LiveSwitcher.app`，启动应用，并确认应用进程能够持续运行。

## Release Install Notes / 发布版安装说明

The current public release ships as `LiveSwitcher-macOS-v0.1.1.zip` containing
`LiveSwitcher.app`.

当前公开发布版为 `LiveSwitcher-macOS-v0.1.1.zip`，压缩包内包含 `LiveSwitcher.app`。

The app is ad-hoc signed and not notarized. On first launch, macOS Gatekeeper may
show a warning. Open it from **System Settings -> Privacy & Security -> Open
Anyway**, or build from source locally.

应用使用 ad-hoc 签名，尚未经过 Apple notarization。首次启动时，macOS Gatekeeper 可能会显示安全提示。可以在 **系统设置 -> 隐私与安全性 -> 仍要打开** 中允许打开，或直接从源码本地构建。

## Permissions / 权限

Page-clicker interception mode requires Accessibility permission:

翻页笔拦截模式需要辅助功能权限：

1. Open **System Settings -> Privacy & Security -> Accessibility**.
2. Add `LiveSwitcher.app`.
3. Enable the permission.
4. Restart the app.

1. 打开 **系统设置 -> 隐私与安全性 -> 辅助功能**。
2. 添加 `LiveSwitcher.app`。
3. 开启权限。
4. 重启应用。

Presentation automation may also request Apple Events permission when controlling
Keynote or compatible presentation apps.

控制 Keynote 或兼容演示应用时，系统也可能请求 Apple Events 权限。

## Repository Shape / 仓库结构

```text
.
├── Package.swift
├── Makefile
├── script/build_and_run.sh
├── Sources/AnnualMeetingSwitcher/
│   ├── Package.swift
│   ├── build_v33.sh
│   ├── LiveSwitcher.entitlements
│   └── Sources/AnnualMeetingSwitcher/
│       ├── App.swift
│       ├── AppConfiguration.swift
│       ├── ContentView.swift
│       ├── ViewModel.swift
│       ├── Engines/
│       ├── Models/
│       ├── Output/
│       └── Views/
└── .github/workflows/
    ├── smoke-tests.yml
    └── release.yml
```

## No License / 无许可证

No open-source license is provided. The code is publicly visible, but all rights
are reserved by the repository owner unless a license is added later.

本仓库未提供开源许可证。代码虽然公开可见，但在未来添加许可证之前，仓库所有者保留全部权利。
