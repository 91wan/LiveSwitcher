# LiveSwitcher v0.3.5 Workspace Guard

Use this guard before local validation, PR push, and release tagging.

发布 / 推送 / 打 tag 前先运行本门禁，避免在脏工作区或残缺快照上继续发布。

## Commands

```bash
./script/check_workspace_guard.sh --dev
./script/check_workspace_guard.sh --release
./script/test_workspace_guard.sh
```

## Dev Mode

`--dev` must pass before build/test work starts.

- The current directory is inside a git worktree.
- `HEAD` is readable.
- `origin` exists.
- No tracked files are deleted.
- No tracked files are modified.
- No untracked files are present.

## Release Mode

`--release` is stricter and is intended for local pre-tag checks.

- Includes all `--dev` checks.
- Current branch must be `main`.
- `origin/main` must be fetchable.
- `HEAD` must exactly match `origin/main`.
- No local-only commit may exist before tagging.

## 中文验收

- 如果有 tracked 文件被删除，必须失败并提示 `deleted tracked files found`。
- 如果有修改但未提交的 tracked 文件，必须失败并提示 `workspace has uncommitted changes`。
- 如果有未跟踪文件，必须失败并提示 `untracked files found`。
- 发布模式不在 `main` 时，必须失败。
- 发布模式 `HEAD` 与 `origin/main` 不一致时，必须失败。

## Why This Exists

`v0.3.5` was added after a local public snapshot showed tracked deletions while
still pointing at the latest release commit. The guard makes that state visible
and blocks accidental build, tag, or release work from a damaged checkout.

本版本的重点不是新增 UI，而是把“本地状态是否可发布”变成可重复检查的硬门禁。
