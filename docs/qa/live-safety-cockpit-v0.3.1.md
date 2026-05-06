# LiveSwitcher v0.3.1 Live Safety Cockpit Navigation

Use the Safety Cockpit before a live run when the operator needs a larger, focused readiness view instead of the compact `? -> Preflight` popover. v0.3.1 also makes non-mutating cockpit guidance buttons open the matching main-console page.

开演前如果需要比 `? -> Preflight` 更大的现场检查视图，使用 Safety Cockpit / 现场安全台。v0.3.1 还让安全台里的非状态修改类引导按钮可以直接打开主控制台对应页面。

## What It Shows

- Overall state: `Ready`, `Needs Review`, or `Not Ready`.
- Pass / warn / fail counts.
- The highest-priority fail and warn rows first.
- Display, projection, playback, audio, overlay, and control state.
- Recent sanitized support events.
- `Copy Support` and `Save Support...` for text-only support handoff.
- Non-mutating navigation actions: `Open preview`, `Open audio mixer`, and `Open overlays`.

## 显示内容

- 总状态：`Ready`、`Needs Review` 或 `Not Ready`。
- Pass / Warn / Fail 数量。
- 失败和警告项优先显示。
- 显示、投射、播放、音频、叠层、控制状态。
- 最近的脱敏支持事件。
- `Copy Support` 和 `Save Support...` 纯文本支持报告导出。
- 非状态修改类导航动作：`Open preview`、`Open audio mixer`、`Open overlays`。

## How To Open

1. Click `?`.
2. Switch to `Preflight`.
3. Click `Open Cockpit`.

Alternative: use the macOS menu `现场控制 -> 打开现场安全台`.

## 打开方式

1. 点击 `?`。
2. 切到 `Preflight`。
3. 点击 `Open Cockpit`。

也可以使用 macOS 菜单：`现场控制 -> 打开现场安全台`。

## Safety Limits

- `Clear overlays` may directly clear countdown, ticker, and lower third.
- `Turn off panic` may directly disable active panic blackout.
- `Open preview`, `Open audio mixer`, and `Open overlays` may switch the main console tab, but they do not mutate show state.
- Hardware rows stay disabled and require real external-display checks.
- Manual review rows stay disabled and require operator judgment.
- The cockpit does not change playlists, BGM library, wallpaper library, audio strategy, projection target, or playback source.

## 安全边界

- `Clear overlays` 可以直接清空倒计时、游动字幕和人名条。
- `Turn off panic` 可以直接关闭已开启的老板键。
- `Open preview`、`Open audio mixer`、`Open overlays` 可以切换主控制台页面，但不修改现场状态。
- 硬件检查项保持禁用，必须由现场人员用真实外接屏验证。
- 人工复核项保持禁用，必须由现场人员判断。
- 安全台不会修改节目列表、BGM 音乐库、壁纸库、音频策略、投射目标或当前播放源。

## Acceptance Checklist

- The cockpit opens in a separate window.
- The main three-tab console remains unchanged.
- Fail and warn rows appear before pass rows.
- No external display is shown as not ready, not fake-passed.
- Active panic exposes `Turn off panic`.
- Active overlays expose `Clear overlays`.
- `Open preview`, `Open audio mixer`, and `Open overlays` switch the main console to the matching page.
- Navigation actions do not change playback, projection, audio routing, overlays, playlist, BGM library, or wallpaper library.
- Support report export remains text-only and sanitized.

## 验收清单

- 安全台在独立窗口打开。
- 主控制台仍保持三页结构不变。
- 失败和警告项排在通过项之前。
- 没有外接屏时显示未就绪，不得假通过。
- 老板键开启时显示 `Turn off panic`。
- 有叠层上屏时显示 `Clear overlays`。
- `Open preview`、`Open audio mixer`、`Open overlays` 会把主控制台切到对应页面。
- 导航动作不会改变播放、投射、音频路由、叠层、节目列表、BGM 音乐库或壁纸库。
- 支持报告仍为纯文本且已脱敏。
