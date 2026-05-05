# LiveSwitcher v0.2.4 Preflight Summary Guide

## Purpose

v0.2.4 adds an overall readiness summary to `? -> Preflight`. The goal is to help operators triage quickly before reading every detailed check row.

v0.2.4 在 `? -> Preflight` 中新增总就绪状态。目标是让现场人员先快速判断风险，再逐条阅读详细检查项。

## Status Rules

| Summary | Rule | Operator meaning |
| --- | --- | --- |
| `Ready` | All checks pass. | Current runtime state is ready within the in-app checks. |
| `Needs review` | No failures, at least one warning. | Review warning rows before going live. |
| `Not ready` | At least one failure. | Do not project until fail rows are resolved. |

## 状态规则

| 总览 | 规则 | 现场含义 |
| --- | --- | --- |
| `Ready` | 所有检查通过。 | 在 App 可检测范围内，当前运行状态已就绪。 |
| `Needs review` | 没有失败项，但至少有一个警告。 | 上线前必须检查警告行是否符合现场意图。 |
| `Not ready` | 至少有一个失败项。 | 失败项解决前不要投射。 |

## What The Counts Mean

- `P`: pass rows.
- `W`: warning rows.
- `F`: fail rows.

The counts are deterministic and are also included in `Copy Report`.

## 计数含义

- `P`：通过项数量。
- `W`：警告项数量。
- `F`：失败项数量。

这些计数是确定性结果，也会写入 `Copy Report`。

## Acceptance Checks

- Missing external display must make the summary `Not ready`.
- Panic blackout active must make the summary `Not ready`.
- Auto-next enabled without other failures must make the summary `Needs review`.
- A fully prepared snapshot must make the summary `Ready`.
- `Copy Report` must include the summary line and pass/warn/fail counts.

## 验收检查

- 未检测到外接屏时，总览必须是 `Not ready`。
- 老板键黑屏激活时，总览必须是 `Not ready`。
- 没有失败项但视频自动下一条开启时，总览必须是 `Needs review`。
- 完整准备好的状态，总览必须是 `Ready`。
- `Copy Report` 必须包含总览行和 pass/warn/fail 计数。
