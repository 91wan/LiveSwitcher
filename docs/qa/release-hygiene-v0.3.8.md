# LiveSwitcher v0.3.8 Release Hygiene

## English

`v0.3.8` keeps the release-trust gates and tightens Preflight behavior. PPT Mode now reports PASS only when its current source can reasonably use page-clicker takeover, and navigation actions are recorded in the sanitized support event timeline.

The public build remains source-available, ad-hoc signed, and not notarized. Release tags still must match `origin/main`, and the packaged app still comes from `dist/LiveSwitcher.app`.

## 中文

`v0.3.8` 保留发布可信门禁，并收紧 Preflight 行为。PPT Mode 只有在当前节目适合翻页笔接管时才 PASS，导航类预检动作也会写入脱敏支持事件时间线。

当前公开构建仍然是 source-available、ad-hoc signed、未 notarized。Release tag 仍必须指向 `origin/main`，发布包仍从 `dist/LiveSwitcher.app` 生成。
