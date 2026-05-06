# LiveSwitcher v0.2.7 Diagnostics Guide

This guide explains how operators should collect a sanitized diagnostics report before filing a bug or handing a live-room issue to a developer.

本指南说明现场人员如何在提交 bug 或交接现场问题前，导出一份已脱敏的诊断报告。

## When to Use

- Use diagnostics when the app behavior is unclear, intermittent, or hard to reproduce.
- Use it after checking `? -> Preflight -> Needs attention`.
- Do not use it as proof that external-display unplug testing passed; hardware tests still need real hardware.

## 何时使用

- 当 App 行为不稳定、难以复现或需要交给开发者分析时使用。
- 建议先查看 `? -> Preflight -> Needs attention`，再复制或保存诊断报告。
- 诊断报告不能替代外接屏拔线测试；硬件项仍必须用真实硬件复测。

## Operator Steps

1. Open LiveSwitcher.
2. Click the `?` button in the top-right toolbar.
3. Switch from `Help` to `Preflight`.
4. Review the summary and `Needs attention` rows.
5. Click `Copy Diagnostics` for chat/GitHub issue handoff, or `Save...` to write `LiveSwitcher-Diagnostics-v0.2.7.txt`.
6. Attach the copied/saved text with a short description of what the operator clicked before the issue happened.

## 操作步骤

1. 打开 LiveSwitcher。
2. 点击右上角 `?` 按钮。
3. 从 `Help` 切到 `Preflight`。
4. 查看总览和 `Needs attention` 项。
5. 点击 `Copy Diagnostics` 复制诊断文本，或点击 `Save...` 保存 `LiveSwitcher-Diagnostics-v0.2.7.txt`。
6. 提交问题时附上诊断文本，并简要说明问题发生前点击了什么。

## Privacy Limits

Diagnostics intentionally include:

- App version.
- macOS version and CPU architecture.
- Preflight pass/warn/fail summary.
- Projection, audio, overlay, wallpaper, playlist, BGM, and live-control state counts.
- Preflight check statuses and action recommendations.

Diagnostics intentionally exclude:

- Local absolute paths.
- `file://` URLs.
- Raw media filenames.
- Raw playlist item titles.
- Customer or event content.
- Tokens, credentials, or environment secrets.

## 隐私边界

诊断报告会包含：

- App 版本。
- macOS 版本和 CPU 架构。
- 现场检查 pass/warn/fail 总览。
- 投射、音频、叠层、壁纸、节目列表、BGM 和现场控制状态数量。
- 现场检查项状态和建议操作。

诊断报告不会包含：

- 本机绝对路径。
- `file://` URL。
- 原始媒体文件名。
- 原始节目标题。
- 客户或活动内容。
- Token、凭证或环境秘密。

## Acceptance Checklist

- `Copy Diagnostics` produces text that can be pasted into a GitHub issue.
- `Save...` writes a `.txt` diagnostics file.
- The report contains `LiveSwitcher Diagnostics v0.2.7`.
- The report does not contain `/Users/`, `file://`, raw media filenames, or customer text.
- The report reflects active panic, speaker mode, BGM takeover, overlays, and display readiness when those states are active.

## 验收清单

- `Copy Diagnostics` 生成的文本可直接粘贴到 GitHub issue。
- `Save...` 可以保存 `.txt` 诊断文件。
- 报告包含 `LiveSwitcher Diagnostics v0.2.7`。
- 报告不包含 `/Users/`、`file://`、原始媒体文件名或客户文本。
- 当老板键、主讲人模式、BGM 接管、叠层或显示器异常处于激活状态时，报告必须反映这些状态。
