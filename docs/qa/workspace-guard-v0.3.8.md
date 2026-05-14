# LiveSwitcher v0.3.8 Workspace Guard

## English

The workspace guard remains the first local release gate for v0.3.8. `--dev` blocks dirty worktrees. Release workflows additionally verify that the tag commit is exactly `origin/main`, preventing old tags or side-branch commits from producing public artifacts.

## 中文

工作区保护仍然是 v0.3.8 本地发布第一道门禁。`--dev` 会阻止脏工作区。GitHub Release workflow 额外校验 tag commit 必须等于 `origin/main`，避免旧 tag 或 side branch commit 生成公开发布包。
