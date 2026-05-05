# LiveSwitcher v0.2.5 Preflight Focus Guide

## Purpose

v0.2.5 makes `? -> Preflight` faster to use on site by separating urgent rows from the full checklist. Operators should start with `Needs attention`, then switch to `All checks` only when they need a complete audit.

v0.2.5 将 `? -> Preflight` 调整为更适合现场使用：先显示需要处理的行，再保留完整检查列表。现场人员应先看 `Needs attention`，只有需要完整审计时再切到 `All checks`。

## Recommended Workflow

1. Open `? -> Preflight`.
2. Read the summary card first: `Ready`, `Needs review`, or `Not ready`.
3. Stay on `Needs attention` and handle fail/warn rows.
4. Use safe one-click actions only when appropriate: `Clear overlays` or `Turn off panic`.
5. Switch to `All checks` for a full pass/warn/fail audit.
6. Use `Copy Report` when handing state to another operator or filing a debug report.

## 推荐流程

1. 打开 `? -> Preflight`。
2. 先看总览卡：`Ready`、`Needs review` 或 `Not ready`。
3. 保持在 `Needs attention`，优先处理 fail/warn 行。
4. 只在合适时使用安全一键操作：`Clear overlays` 或 `Turn off panic`。
5. 需要完整审计时切到 `All checks`。
6. 交接给其他现场人员或记录 debug 信息时使用 `Copy Report`。

## Behavior Contract

- `Needs attention` shows only failed and warning rows.
- `All checks` shows every preflight row.
- `Copy Report` always includes every row, even when `Needs attention` is selected.
- `Clear overlays` clears countdown, ticker, and lower third.
- `Turn off panic` disables active panic blackout.
- Navigation actions only switch existing tabs and do not change playback, playlists, audio strategy, wallpaper library, BGM library, or external-display state.

## 行为约定

- `Needs attention` 只显示失败项和警告项。
- `All checks` 显示全部检查行。
- `Copy Report` 始终包含全部检查行，即使当前选择的是 `Needs attention`。
- `Clear overlays` 会清空倒计时、游动字幕和人名条。
- `Turn off panic` 会关闭已激活的老板键黑屏。
- 跳转类操作只切换已有页面，不改变播放、节目列表、音频策略、壁纸库、BGM 音乐库或外接屏状态。

## Acceptance Checks

- A snapshot with no warnings or failures leaves `Needs attention` empty and the summary `Ready`.
- A missing external display appears in `Needs attention`.
- Active panic blackout appears in `Needs attention` with `Turn off panic`.
- Active overlays appear in `Needs attention` with `Clear overlays`.
- `Copy Report` includes the full report and version `0.2.5`.

## 验收检查

- 没有警告和失败时，`Needs attention` 为空，且总览为 `Ready`。
- 未检测到外接屏时，该行必须出现在 `Needs attention`。
- 老板键黑屏激活时，该行必须出现在 `Needs attention`，并提供 `Turn off panic`。
- 叠层激活时，该行必须出现在 `Needs attention`，并提供 `Clear overlays`。
- `Copy Report` 必须包含完整报告和版本 `0.2.5`。
