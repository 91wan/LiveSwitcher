# LiveSwitcher v0.3.7 Release Hygiene

## English

`v0.3.7` keeps the v0.3.6 release-trust gates and hardens Panic audio consistency. Panic blackout is now part of the unified routing calculation, so runtime audio, Preflight, and Support Report agree on effective media/BGM volume.

The public build remains source-available, ad-hoc signed, and not notarized. Release tags still must match `origin/main`, and the packaged app still comes from `dist/LiveSwitcher.app`.

## 中文

`v0.3.7` 保留 v0.3.6 的发布可信门禁，并加固老板键音频一致性。Panic 静音已进入统一路由计算，运行时音频、Preflight、Support Report 对媒体/BGM 实际音量的判断保持一致。

当前公开构建仍然是 source-available、ad-hoc signed、未 notarized。Release tag 仍必须指向 `origin/main`，发布包仍从 `dist/LiveSwitcher.app` 生成。
