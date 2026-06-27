#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dev}"

fail() {
  echo "workspace guard failed: $*" >&2
  exit 1
}

usage() {
  echo "usage: $0 [--dev|--release]" >&2
}

case "$MODE" in
  --dev|dev)
    MODE="dev"
    ;;
  --release|release)
    MODE="release"
    ;;
  *)
    usage
    exit 2
    ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not inside a git repository"
git rev-parse --verify HEAD^{commit} >/dev/null 2>&1 || fail "HEAD is not readable"
git remote get-url origin >/dev/null 2>&1 || fail "missing origin remote"

deleted_paths="$(git status --porcelain=v1 --untracked-files=all | awk 'substr($0, 1, 1) == "D" || substr($0, 2, 1) == "D" {print substr($0, 4)}')"
if [[ -n "$deleted_paths" ]]; then
  echo "$deleted_paths" >&2
  fail "deleted tracked files found"
fi

untracked_paths="$(git status --porcelain=v1 --untracked-files=all | awk 'substr($0, 1, 2) == "??" {print substr($0, 4)}')"
if [[ -n "$untracked_paths" ]]; then
  echo "$untracked_paths" >&2
  fail "untracked files found"
fi

dirty_paths="$(git status --porcelain=v1 --untracked-files=all)"
if [[ -n "$dirty_paths" ]]; then
  echo "$dirty_paths" >&2
  fail "workspace has uncommitted changes"
fi

if [[ "$MODE" == "release" ]]; then
  branch="$(git branch --show-current)"
  [[ "$branch" == "main" ]] || fail "release mode requires branch main"

  git fetch --quiet origin main || fail "failed to fetch origin/main"
  git rev-parse --verify refs/remotes/origin/main^{commit} >/dev/null 2>&1 || fail "origin/main is not readable"

  head_sha="$(git rev-parse HEAD)"
  origin_sha="$(git rev-parse refs/remotes/origin/main)"
  [[ "$head_sha" == "$origin_sha" ]] || fail "HEAD must match origin/main"

  local_only_count="$(git rev-list --count refs/remotes/origin/main..HEAD)"
  [[ "$local_only_count" == "0" ]] || fail "local-only commits found"
fi

if [[ -x script/check_complexity_budget.sh ]]; then
  script/check_complexity_budget.sh "$MODE"
fi

echo "workspace guard passed ($MODE)"
