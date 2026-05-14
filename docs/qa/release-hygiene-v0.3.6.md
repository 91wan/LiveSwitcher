# LiveSwitcher v0.3.6 Release Hygiene

## English

`v0.3.6` hardens the public release path. A tag release must match `origin/main`, the app version is checked against the root `VERSION` file, and the packaged app is built from `dist/LiveSwitcher.app`.

The public build remains source-available, ad-hoc signed, and not notarized. Hardened runtime signing options are enabled for the ad-hoc package so the same path can later accept a Developer ID identity.

## 中文

`v0.3.6` 重点加固公开发布路径：tag release 必须指向 `origin/main`，应用版本必须和根目录 `VERSION` 一致，发布包统一从 `dist/LiveSwitcher.app` 生成。

当前公开构建仍然是 source-available、ad-hoc signed、未 notarized。脚本已启用 hardened runtime 签名参数，后续接入 Developer ID 后可以沿用同一打包路径。
