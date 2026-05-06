# LiveSwitcher v0.3.2 Action Guidance

Use this guide to verify that `? -> Preflight` and `Live Safety Cockpit / 现场安全台` show the right kind of operator action before a live run.

本指南用于验证 `? -> Preflight` 和 `Live Safety Cockpit / 现场安全台` 在开演前是否用正确方式展示现场操作。

## Action Types

- Safe one-click: `Clear overlays` and `Turn off panic` are clickable and may directly change reversible safety state.
- Navigation: `Open preview`, `Open audio mixer`, and `Open overlays` are clickable and only switch the main console page.
- Operator guidance: `Needs hardware` and `Manual review` are non-clickable badges. They require real hardware or human judgment.

## 操作类型

- 安全一键修复：`Clear overlays` 和 `Turn off panic` 可点击，并且只允许修改可逆的安全状态。
- 页面导航：`Open preview`、`Open audio mixer`、`Open overlays` 可点击，但只切换主控制台页面。
- 现场人员指引：`Needs hardware` 和 `Manual review` 显示为不可点击徽标，必须由真实硬件或现场人员判断。

## Operator Flow

1. Open `? -> Preflight`.
2. Review `Needs attention`.
3. Click only safe one-click or navigation buttons when appropriate.
4. Treat hardware/manual badges as instructions, not broken controls.
5. Open `Safety Cockpit` when a larger readiness view is needed.

## 现场流程

1. 打开 `? -> Preflight`。
2. 先查看 `Needs attention`。
3. 只在合适时点击安全一键修复或页面导航按钮。
4. 把硬件/人工徽标当作指引，不要当作失效按钮。
5. 需要更大视图时打开 `Safety Cockpit / 现场安全台`。

## Acceptance Checklist

- `Needs hardware` is visible when no external display is detected.
- `Needs hardware` is not clickable and does not mutate state.
- `Manual review` is visible for PPT mode review.
- `Manual review` is not clickable and does not mutate state.
- `Clear overlays` clears countdown, ticker, and lower third.
- `Turn off panic` disables active panic blackout.
- Navigation buttons open the matching main-console tab without changing playback, projection, audio routing, playlists, BGM library, wallpaper library, or overlays.
- `Copy Report`, `Copy Support`, and `Save Support...` remain available.

## 验收清单

- 未检测到外接屏时显示 `Needs hardware`。
- `Needs hardware` 不可点击，且不会修改状态。
- PPT 模式复核显示 `Manual review`。
- `Manual review` 不可点击，且不会修改状态。
- `Clear overlays` 可以清空倒计时、游动字幕和人名条。
- `Turn off panic` 可以关闭已开启的老板键黑屏。
- 页面导航按钮会打开对应主控制台页签，但不改变播放、投射、音频路由、节目列表、BGM 音乐库、壁纸库或叠层。
- `Copy Report`、`Copy Support` 和 `Save Support...` 仍然可用。
