# LiveSwitcher v0.3.4 Overlay Reliability

Use this guide to verify that live overlays are deterministic, operator-visible, and safe to include in support handoff reports.

本指南用于验证现场叠层状态稳定、可被操作人员识别，并且可以安全进入支持报告。

## What Changed

- Preflight now reports active overlay types: countdown, ticker, and lower third.
- Countdown expiry uses a named tick path so the final second and auto-stop behavior are regression-tested.
- Countdown timers are explicitly added to the common run loop mode.
- Diagnostics and Support Report include sanitized overlay types and countdown remaining time.
- Reports still exclude overlay text, lower-third names/titles, local paths, filenames, file URLs, and customer content.

## 更新内容

- 现场检查现在显示正在上屏的叠层类型：倒计时、游动字幕、人名条。
- 倒计时结束逻辑走具名 tick 路径，最后一秒和自动停止行为有回归测试。
- 倒计时定时器明确加入 common run-loop mode。
- 诊断报告和支持报告包含脱敏后的叠层类型与倒计时剩余时间。
- 报告仍不包含叠层文字、人名条姓名/职务、本机路径、文件名、file URL 或客户内容。

## Operator Check

1. Open `叠层 / 字幕`.
2. Start a countdown, a ticker, and a lower third.
3. Open `? -> Preflight` and confirm `Active Overlays` lists `countdown`, `ticker`, and `lower third`.
4. Confirm the countdown row includes remaining seconds but does not display the custom countdown title.
5. Use `Copy Support` and confirm the support text contains overlay types, not the entered ticker or lower-third text.
6. Click `Clear overlays` and confirm all three overlay types leave the output.

## 现场检查

1. 打开 `叠层 / 字幕`。
2. 启动倒计时、游动字幕和人名条。
3. 打开 `? -> Preflight`，确认 `Active Overlays` 显示 `countdown`、`ticker`、`lower third`。
4. 确认倒计时显示剩余秒数，但不显示自定义倒计时标题。
5. 使用 `Copy Support`，确认支持文本只包含叠层类型，不包含输入的字幕或人名条文字。
6. 点击 `Clear overlays`，确认三类叠层全部下屏。

## Automated Coverage

- `SwitcherViewModelSmokeTests/testCountdownTickAutoStopsAtZero`
- `SwitcherViewModelSmokeTests/testRestartingCountdownReplacesRemainingSeconds`
- `SwitcherViewModelSmokeTests/testClearAllOverlaysResetsCountdownTickerAndLowerThird`
- `LivePreflightTests/testActiveOverlaysReportOverlayCount`
- `LivePreflightTests/testOverlayReportsDoNotLeakOverlayContent`

## 自动化覆盖

- `SwitcherViewModelSmokeTests/testCountdownTickAutoStopsAtZero`
- `SwitcherViewModelSmokeTests/testRestartingCountdownReplacesRemainingSeconds`
- `SwitcherViewModelSmokeTests/testClearAllOverlaysResetsCountdownTickerAndLowerThird`
- `LivePreflightTests/testActiveOverlaysReportOverlayCount`
- `LivePreflightTests/testOverlayReportsDoNotLeakOverlayContent`
