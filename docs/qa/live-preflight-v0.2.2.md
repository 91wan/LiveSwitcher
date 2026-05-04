# LiveSwitcher v0.2.2 Live Preflight Guide

This guide explains how to use the in-app `Live Preflight / 现场检查` panel before a show. It complements the manual hardware checklist in `docs/qa/live-regression-v0.2.1.md`; it does not replace external-display unplug testing.

本指南说明如何在演出前使用 App 内置的 `Live Preflight / 现场检查` 面板。它用于补充 `docs/qa/live-regression-v0.2.1.md` 的人工硬件复测清单，不能替代外接屏拔线测试。

## When To Use It / 什么时候使用

- Before audience entry / 观众入场前
- After connecting or reconnecting an external display / 连接或重新连接外接屏后
- After loading a new playlist, BGM library, wallpaper, or overlay / 加载新的节目、BGM、壁纸或叠层后
- Before handing the machine to another operator / 交接给另一位现场操作人员前
- When filing a support/debug note / 需要提交支持或调试记录时

## Steps / 操作步骤

1. Launch `LiveSwitcher.app`.
2. Click the top `?` button.
3. Switch the segmented control from `Help` to `Preflight`.
4. Review each group: `Display`, `Audio`, `Playback`, `Overlays`, `Controls`.
5. Click `Copy Report` if a plain-text record is needed.

1. 启动 `LiveSwitcher.app`。
2. 点击顶部 `?` 按钮。
3. 将分段开关从 `Help` 切到 `Preflight`。
4. 逐项查看 `Display`、`Audio`、`Playback`、`Overlays`、`Controls`。
5. 如需留档或提交问题，点击 `Copy Report` 复制纯文本报告。

## How To Read Status / 如何判断状态

- `Pass`: the current state is acceptable for that check.
- `Warn`: the state may be intentional, but should be confirmed before going live.
- `Fail`: the state is unsafe or not ready. Resolve it before projection.

- `Pass`：当前状态可接受。
- `Warn`：状态可能是有意设置，但开演前需要确认。
- `Fail`：状态不安全或未就绪，应先处理再投射。

## Check Groups / 检查分组

### Display / 显示

Checks whether an external display is detected and whether projection is currently active. If no external display is detected, the panel must show not ready and recommend not projecting.

检查是否检测到外接屏，以及当前是否正在投射。若未检测到外接屏，面板必须显示未就绪，并提示不要投射。

### Audio / 音频

Reports BGM library readiness, speaker mode, BGM takeover, and effective media/BGM output volume.

报告 BGM 音乐库、主讲人模式、BGM 接管，以及媒体/BGM 的实际输出音量。

### Playback / 播放

Reports current program selection, wallpaper fallback readiness, and the auto-next video setting.

报告当前节目选择、壁纸回退是否准备好，以及视频播毕自动下一条设置。

### Overlays / 叠层

Reports how many overlays are currently live. Active overlays are not always wrong, but they should be intentional before a show starts.

报告当前有多少叠层正在上屏。叠层开启不一定是错误，但开演前必须确认这是有意状态。

### Controls / 控制

Reports panic blackout and PPT mode. Panic blackout is a fail state because output is blacked out and audio is muted.

报告老板键和 PPT 模式。老板键开启属于失败状态，因为输出已切黑且音频已静音。

## Copy Report / 复制报告

`Copy Report` writes a plain-text summary to the macOS clipboard. Use it for:

- Operator handoff notes
- Incident review
- Support/debug messages
- GitHub issue context

`Copy Report` 会把纯文本摘要写入 macOS 剪贴板。适合用于：

- 现场交接记录
- 故障复盘
- 支持/调试沟通
- GitHub issue 上下文

## Limits / 限制

- The panel can detect whether an external display is currently available, but it cannot prove that a cable unplug test has passed.
- The panel reads current app state; it does not click controls or change playback/output behavior.
- The panel does not replace manual audio listening checks in the room.

- 面板可以检测当前是否有外接屏，但不能证明拔线测试已经通过。
- 面板只读取当前 App 状态，不会自动点击控件，也不会改变播放或输出行为。
- 面板不能替代现场真实听音检查。
