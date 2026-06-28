# Complexity Budget Gate

This gate keeps the post-stable codebase from regrowing large, unowned files.
It is a maintenance guard only; behavior changes: none.

## Categories

`script/check_complexity_budget.sh` scans tracked Swift files with `git ls-files`.
Every `Views/**/*.swift` file is classified instead of relying on a hand-written
directory list:

- `Sources/.../Views/*.swift`: `top-level-view`, 300 lines
- `Sources/.../Views/*/*.swift`: `focused-subview`, 250 lines
- `Sources/.../Views/*/*/*.swift`: `focused-subview`, 250 lines
- `Sources/.../Output/*.swift`: `top-level-view`, 300 lines
- `Sources/.../Models/*.swift`: `model-reducer`, 400 lines
- `Sources/.../Runtime/*.swift`: `model-reducer`, 400 lines
- `Sources/.../ViewModel*.swift`: `model-reducer`, 400 lines
- `Sources/.../Tests/.../*Support.swift`: `test-helper`, 250 lines
- `Sources/.../Tests/.../*Tests.swift`: `test-file`, 500 lines
- each test file also has a `source-contains` budget of 15

New `Views` subdirectories are therefore covered by default. If a new file is
over budget, the preferred fix is to split it before merging.

## Allowlist Manifest

Over-budget exceptions live in `docs/architecture/complexity-allowlist.tsv`.
The manifest format is:

```text
category	path	limit	actual	reason	target_version	owner
```

The script validates every row before checking budgets:

- `category` must be one of the known budget categories.
- `path` must exist.
- `limit` must match the current category limit.
- `actual` must match the current line count or `source.contains` count.
- `reason` must explain why the exception still exists.
- `target_version` must name the expected burn-down target or accepted risk.
- `owner` must be non-empty.

Do not add an allowlist row as a default response to a failure. A new row is only
acceptable when the PR explains why the file cannot be split in that slice and
records a concrete owner plus target.

## Burn-Down Rule

When a file drops below budget, remove its allowlist row in the same PR. When a
file changes but remains over budget, update `actual` and keep the reason honest.
Source-string test debt should be replaced by model, reducer, layout, or policy
tests rather than moved into another source-string assertion.

## Post-v0.5.0 Burn-Down Snapshot - 2026-06-28

After the post-stable runtime, ViewModel, test-suite, and source-contract
burn-down simplification slices, the allowlist is empty. Production-code,
oversized test-file, and source-string allowlist debt are all retired.

- Allowlist rows: 0
- Production-code allowlist rows: 0
- Test-file allowlist rows: 0
- Source-string allowlist rows: 0
- Source-string actual total: 0
- Source-string allowlist gate: source-contains allowlist rows are now forbidden
- Removed production/test-file debt entries: `ViewModel.swift`, `AudioRuntimeOwnershipTests.swift`, `PersistentStateRuntimeLoadBoundaryTests.swift`

The removed entries cover completed ViewModel internal-store splits, root-shell
cleanup, Audio runtime ownership suite split, Persistent runtime load boundary
suite split, and source-string replacements for live layout and run-desk
coverage. The remaining source-string rows were replaced by behavior, model,
reducer, policy, and fixture-backed gate tests through the final source-contract
burn-down slices.

Future post-stable work should stop unless there is a concrete P0/P1,
release-delivery issue, or user-visible stability fix with bounded acceptance.

No release is triggered by this allowlist burn-down. It is internal maintenance
with behavior changes: none.
