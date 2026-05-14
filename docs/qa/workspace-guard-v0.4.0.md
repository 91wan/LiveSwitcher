# LiveSwitcher v0.4.0 Workspace Guard

## English

The workspace guard remains the first local release gate for v0.4.0. `--dev` blocks dirty worktrees. Release workflows additionally verify that the tag commit is exactly `origin/main`, preventing old tags or side-branch commits from producing public artifacts.

`v0.4.0` adds core-state services, so maintainers should run the full guard/build/test/package sequence before tagging. Do not release from a branch that only contains partial service extraction.

## 中文

工作区保护仍然是 v0.4.0 本地发布第一道门禁。`--dev` 会阻止脏工作区。GitHub Release workflow 额外校验 tag commit 必须等于 `origin/main`，避免旧 tag 或 side branch commit 生成公开发布包。

`v0.4.0` 新增核心状态 service，维护者打 tag 前必须跑完整 guard/build/test/package 流程。不要从只完成部分 service 拆分的分支发布。
