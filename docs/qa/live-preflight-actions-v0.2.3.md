# LiveSwitcher v0.2.3 Preflight Actions Guide

## Purpose

This guide explains how operators should use the `? -> Preflight` panel before a live run. v0.2.3 adds safe action buttons to the read-only v0.2.2 preflight report.

本文说明现场人员如何在开演前使用 `? -> Preflight` 面板。v0.2.3 在 v0.2.2 的只读检查报告基础上增加了安全操作按钮。

## Safety Rule: Safe One-Click

Only reversible, low-risk safety fixes are allowed to mutate app state from Preflight:

- `Clear overlays`: clears countdown, ticker, and lower third.
- `Turn off panic`: disables active panic blackout.

All other actions either navigate to an existing page or stay disabled/manual. Preflight must not automatically change playlists, audio strategy, auto-next, wallpaper library, BGM library, playback state, or external-display state.

## 安全规则：Safe One-Click / 安全一键

Preflight 里只有可逆、低风险的安全修复允许直接修改 App 状态：

- `Clear overlays`：清空倒计时、游动字幕和人名条。
- `Turn off panic`：关闭已激活的老板键黑屏。

其他操作只允许跳转到已有页面，或保持禁用/人工处理。Preflight 不得自动修改节目列表、音频策略、自动下一条、壁纸库、BGM 音乐库、播放状态或外接屏状态。

## Operator Workflow

1. Open the `?` button in the top-right control area.
2. Switch from `Help` to `Preflight`.
3. Review all groups: `Display`, `Audio`, `Playback`, `Overlays`, and `Controls`.
4. Use enabled actions only when they match the intended show state.
5. Use `Copy Report` if you need a handoff note, support note, or issue/debug record.
6. Run hardware checks manually when the panel says `Needs hardware`.

## 现场操作流程

1. 点击右上角控制区的 `?` 按钮。
2. 从 `Help` 切换到 `Preflight`。
3. 逐项检查 `Display`、`Audio`、`Playback`、`Overlays`、`Controls`。
4. 只有当操作符合当前演出意图时，才点击已启用的 action。
5. 如需交接、支持沟通或 issue/debug 记录，点击 `Copy Report`。
6. 面板显示 `Needs hardware` 时，必须人工做硬件检查。

## Action Matrix

| Check condition | Action | Behavior |
| --- | --- | --- |
| No external display | `Needs hardware` | Disabled. No state mutation. |
| Projection off or display warning | `Open preview` | Switches to Preview / Switching. |
| No BGM tracks | `Open audio mixer` | Switches to Audio Mixer. |
| BGM takeover active | `Open audio mixer` | Switches to Audio Mixer. |
| No current program | `Open preview` | Switches to Preview / Switching. |
| No wallpaper fallback | `Open preview` | Switches to Preview / Switching. |
| Auto-next video enabled | `Open preview` | Switches to Preview / Switching for queue review. |
| Active overlays | `Clear overlays` | Clears countdown, ticker, and lower third. |
| Panic blackout active | `Turn off panic` | Disables panic blackout. |
| PPT mode | `Manual review` | Disabled. Operator confirms intended state manually. |

## 操作矩阵

| 检查状态 | 操作 | 行为 |
| --- | --- | --- |
| 未检测到外接屏 | `Needs hardware` | 禁用，不修改状态。 |
| 投射关闭或显示告警 | `Open preview` | 跳转到预览 / 切换页。 |
| 没有 BGM 曲目 | `Open audio mixer` | 跳转到音频混音页。 |
| BGM 接管中 | `Open audio mixer` | 跳转到音频混音页。 |
| 没有当前节目 | `Open preview` | 跳转到预览 / 切换页。 |
| 没有壁纸回退 | `Open preview` | 跳转到预览 / 切换页。 |
| 已开启视频自动下一条 | `Open preview` | 跳转到预览 / 切换页检查队列。 |
| 有叠层正在上屏 | `Clear overlays` | 清空倒计时、游动字幕和人名条。 |
| 老板键黑屏已激活 | `Turn off panic` | 关闭老板键黑屏。 |
| PPT 模式 | `Manual review` | 禁用，由现场人员人工确认状态。 |

## Pass / Fail Criteria

- `Clear overlays` must leave countdown, ticker, and lower third inactive.
- `Turn off panic` must leave panic blackout inactive.
- Navigation actions must only switch tabs and close the popover.
- `Needs hardware` and `Manual review` must be disabled and must not mutate runtime state.
- `Copy Report` must include status rows and recommended action lines.

## 通过 / 失败标准

- `Clear overlays` 后倒计时、游动字幕和人名条必须全部下屏。
- `Turn off panic` 后老板键黑屏必须关闭。
- 跳转类操作只能切换页面并关闭弹窗。
- `Needs hardware` 和 `Manual review` 必须禁用，且不得修改运行状态。
- `Copy Report` 必须包含状态行和建议操作行。
