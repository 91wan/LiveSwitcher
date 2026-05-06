# LiveSwitcher v0.2.8 Support Report Guide

This guide explains how to collect a sanitized text-only support report from the app before filing a bug or handing a live-room issue to a developer.

本指南说明如何从 App 内收集脱敏的纯文本支持报告，用于提交 bug 或把现场问题交给开发者排查。

## When To Use It

- Use it after checking `? -> Preflight -> Needs attention`.
- Use it when a problem is intermittent, hard to reproduce, or depends on live-room state.
- Do not use it as proof that external-display unplug testing passed; hardware tests still need real hardware.

## 适用场景

- 建议先查看 `? -> Preflight -> Needs attention`，再复制或保存支持报告。
- 当问题偶发、难复现，或与现场状态有关时使用。
- 支持报告不能替代外接屏拔线硬件测试；硬件项仍需真实硬件验证。

## Operator Steps

1. Open the `?` button.
2. Switch from `Help` to `Preflight`.
3. Review `Needs attention`.
4. Click `Copy Support` for chat/GitHub issue handoff.
5. Click `Save Support...` to write `LiveSwitcher-Support-v0.2.8.txt`.

## 现场操作步骤

1. 点击顶部 `?` 按钮。
2. 从 `Help` 切到 `Preflight`。
3. 先查看 `Needs attention`。
4. 点击 `Copy Support` 复制支持报告。
5. 点击 `Save Support...` 保存 `LiveSwitcher-Support-v0.2.8.txt`。

## Included

Support reports intentionally include:

- App version and generated time.
- Runtime OS and architecture summary.
- Diagnostics summary.
- Full preflight report.
- Recent sanitized event kinds for live controls.

## 包含内容

支持报告会包含：

- App 版本和生成时间。
- 操作系统和架构摘要。
- 诊断摘要。
- 完整现场检查报告。
- 最近的脱敏现场控制事件类型。

## Excluded

Support reports intentionally exclude:

- Screenshots.
- macOS system logs.
- Local file paths and `file://` URLs.
- Raw media filenames and media titles.
- Customer text, overlay text, ticker text, and lower-third text.

## 不包含内容

支持报告不会包含：

- 截图。
- macOS 系统日志。
- 本机文件路径和 `file://` URL。
- 原始媒体文件名和媒体标题。
- 客户文案、叠层文字、游动字幕文字和人名条文字。

## Acceptance Checklist

- `Copy Support` produces text that can be pasted into a GitHub issue.
- `Save Support...` writes a `.txt` file.
- The report contains `LiveSwitcher Support Report v0.2.8`.
- The report contains `[Diagnostics]`, `[Preflight Report]`, and `[Recent Events]`.
- The report does not contain local paths, file URLs, raw media filenames, or customer text.

## 验收清单

- `Copy Support` 生成的文本可直接粘贴到 GitHub issue。
- `Save Support...` 可以保存 `.txt` 文件。
- 报告包含 `LiveSwitcher Support Report v0.2.8`。
- 报告包含 `[Diagnostics]`、`[Preflight Report]` 和 `[Recent Events]`。
- 报告不包含本机路径、file URL、原始媒体文件名或客户文案。
