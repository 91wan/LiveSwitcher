# LiveSwitcher v0.4.0 Release Hygiene

## English

`v0.4.0` keeps the release-trust gates from the v0.3 series and starts the core-state split. Audio routing, projection readiness, presentation automation scripts, and program-queue persistence now have dedicated service/model boundaries with unit coverage.

The public build remains source-available, ad-hoc signed, and not notarized. Release tags still must match `origin/main`, and the packaged app still comes from `dist/LiveSwitcher.app`.

## 中文

`v0.4.0` 延续 v0.3 系列的发布可信门禁，并开始拆分核心状态。音频路由、投射准备、演示自动化脚本、节目队列持久化已经有独立 service/model 边界和单元测试覆盖。

当前公开构建仍然是 source-available、ad-hoc signed、未 notarized。Release tag 仍必须指向 `origin/main`，发布包仍从 `dist/LiveSwitcher.app` 生成。
