#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT_DIR/script/check_workspace_guard.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/liveswitcher-workspace-guard.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "workspace guard test failed: $*" >&2
  exit 1
}

setup_origin() {
  local seed="$TMP_DIR/seed"
  local origin="$TMP_DIR/origin.git"

  git init --bare "$origin" >/dev/null
  git -C "$origin" symbolic-ref HEAD refs/heads/main

  git init -b main "$seed" >/dev/null
  git -C "$seed" config user.email "test@example.com"
  git -C "$seed" config user.name "Workspace Guard Test"
  printf 'initial\n' >"$seed/tracked.txt"
  git -C "$seed" add tracked.txt
  git -C "$seed" commit -m "initial" >/dev/null
  git -C "$seed" remote add origin "$origin"
  git -C "$seed" push -u origin main >/dev/null 2>&1

  printf '%s\n' "$origin"
}

clone_repo() {
  local origin="$1"
  local name="$2"
  local path="$TMP_DIR/$name"

  git clone "$origin" "$path" >/dev/null 2>&1
  git -C "$path" switch main >/dev/null 2>&1
  git -C "$path" config user.email "test@example.com"
  git -C "$path" config user.name "Workspace Guard Test"
  printf '%s\n' "$path"
}

expect_success() {
  local repo="$1"
  local mode="$2"
  local output

  output="$(cd "$repo" && "$GUARD" "$mode" 2>&1)" || fail "expected $mode success, got: $output"
  grep -q "workspace guard passed" <<<"$output" || fail "success output missing pass marker: $output"
}

expect_failure() {
  local repo="$1"
  local mode="$2"
  local expected="$3"
  local output

  if output="$(cd "$repo" && "$GUARD" "$mode" 2>&1)"; then
    fail "expected $mode failure containing '$expected'"
  fi
  grep -qi "$expected" <<<"$output" || fail "failure output did not contain '$expected': $output"
}

advance_origin() {
  local origin="$1"
  local updater="$TMP_DIR/updater"

  git clone "$origin" "$updater" >/dev/null 2>&1
  git -C "$updater" switch main >/dev/null 2>&1
  git -C "$updater" config user.email "test@example.com"
  git -C "$updater" config user.name "Workspace Guard Test"
  printf 'remote change\n' >>"$updater/tracked.txt"
  git -C "$updater" commit -am "remote change" >/dev/null
  git -C "$updater" push origin main >/dev/null 2>&1
}

origin="$(setup_origin)"

clean_repo="$(clone_repo "$origin" clean)"
expect_success "$clean_repo" --dev
expect_success "$clean_repo" --release

deleted_repo="$(clone_repo "$origin" deleted)"
rm "$deleted_repo/tracked.txt"
expect_failure "$deleted_repo" --dev "deleted tracked"

modified_repo="$(clone_repo "$origin" modified)"
printf 'dirty\n' >>"$modified_repo/tracked.txt"
expect_failure "$modified_repo" --dev "uncommitted"

untracked_repo="$(clone_repo "$origin" untracked)"
printf 'new\n' >"$untracked_repo/new.txt"
expect_failure "$untracked_repo" --dev "untracked"

branch_repo="$(clone_repo "$origin" branch)"
git -C "$branch_repo" switch -c feature >/dev/null
expect_failure "$branch_repo" --release "requires branch main"

drift_repo="$(clone_repo "$origin" drift)"
advance_origin "$origin"
expect_failure "$drift_repo" --release "match origin/main"

echo "workspace guard tests passed"
