# LiveSwitcher v0.3.3 Safety Cockpit Events

Use this guide to verify that the Safety Cockpit recent-event list remains stable when multiple support events happen quickly.

本指南用于验证现场安全台的最近事件列表在短时间内出现多个支持事件时仍保持稳定。

## What Changed

- Recent event rows now use deterministic collision-safe identity.
- Events with the same timestamp second and the same event kind no longer share the same SwiftUI row ID.
- Existing visible rows keep stable identity when the latest-12 cap advances.
- Visible event text, timestamp display, redaction, and the latest-12 cap are unchanged.

## 更新内容

- 最近事件行现在使用确定性的防碰撞标识。
- 同一秒内同类型事件不再共用同一个 SwiftUI row ID。
- 当最新 12 条窗口向前推进时，仍在显示中的事件行保持稳定标识。
- 事件可见文字、时间展示、脱敏逻辑和最新 12 条限制保持不变。

## Operator Check

1. Open `Live Safety Cockpit / 现场安全台`.
2. Trigger two quick safe actions or support exports in the same second if practical.
3. Confirm the recent-event list remains visible and does not flicker, collapse, or drop a same-kind row.
4. Confirm sensitive details remain redacted in support text.

## 现场检查

1. 打开 `Live Safety Cockpit / 现场安全台`。
2. 如果现场可操作，快速触发两次安全动作或支持报告导出。
3. 确认最近事件列表仍可见，不闪烁、不折叠、不丢失同类型事件行。
4. 确认支持文本里的敏感信息仍然被脱敏。

## Automated Coverage

- `LivePreflightTests/testSafetyCockpitRecentEventRowsUseUniqueIDsForRepeatedSameKindEventsInSameSecond`
- `LivePreflightTests/testSafetyCockpitRecentEventRowsKeepLatestTwelveRows`
- `LivePreflightTests/testSafetyCockpitRecentEventIDsStayStableWhenCappedTimelineAdvances`
- Existing support-report redaction tests remain part of the release gate.

## 自动化覆盖

- `LivePreflightTests/testSafetyCockpitRecentEventRowsUseUniqueIDsForRepeatedSameKindEventsInSameSecond`
- `LivePreflightTests/testSafetyCockpitRecentEventRowsKeepLatestTwelveRows`
- `LivePreflightTests/testSafetyCockpitRecentEventIDsStayStableWhenCappedTimelineAdvances`
- 既有支持报告脱敏测试仍属于发布门禁。
