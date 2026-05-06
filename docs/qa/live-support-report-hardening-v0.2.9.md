# LiveSwitcher v0.2.9 Support Report Hardening

Use this guide to verify that Support Report remains useful while removing sensitive details.

本指南用于验证 Support Report 在移除敏感信息的同时，仍然保留可用于排查问题的上下文。

## What Changed

- Redaction now happens at line/detail level instead of replacing the entire report.
- Media and presentation filename tokens are removed even when they are not part of a local path.
- The report still contains diagnostics, preflight, recent events, generated time, and the privacy notice.

## 本次变化

- 脱敏粒度从整份报告收缩到单行/单条细节。
- 媒体和演示文件名即使没有本机路径，也会被移除。
- 报告仍保留运行诊断、现场检查、最近事件、生成时间和隐私说明。

## Operator Check

1. Open `? -> Preflight`.
2. Click `Copy Support`.
3. Paste the text into a temporary note.
4. Confirm the report contains `[Diagnostics]`, `[Preflight Report]`, `[Recent Events]`, and `[Privacy Notice]`.
5. Confirm it does not contain local paths, file URLs, raw media filenames, presentation filenames, overlay text, or customer content.

## 现场检查

1. 打开 `? -> Preflight`。
2. 点击 `Copy Support`。
3. 把文本粘贴到临时记录中。
4. 确认报告包含 `[Diagnostics]`、`[Preflight Report]`、`[Recent Events]` 和 `[Privacy Notice]`。
5. 确认报告不包含本机路径、file URL、原始媒体文件名、演示文件名、叠层文字或客户内容。

## Pass Criteria

- One sensitive event detail must not erase the whole report.
- Filename-like tokens are replaced with `[filename redacted]`.
- Path-like or URL-like details are replaced with `[sensitive detail redacted]`.
- Support report generation does not mutate playback, projection, playlist, audio, overlays, wallpapers, or BGM state.

## 通过标准

- 单条敏感事件不会抹掉整份报告。
- 文件名类 token 会被替换为 `[filename redacted]`。
- 路径或 URL 类细节会被替换为 `[sensitive detail redacted]`。
- 生成支持报告不会修改播放、投射、播放列表、音频、叠层、壁纸或 BGM 状态。
