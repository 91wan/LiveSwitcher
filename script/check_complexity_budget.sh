#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---dev}"

MAX_TOP_LEVEL_VIEW_LINES=300
MAX_FOCUSED_SUBVIEW_LINES=250
MAX_MODEL_REDUCER_LINES=400
MAX_TEST_HELPER_LINES=250
MAX_TEST_FILE_LINES=500
MAX_SOURCE_CONTAINS_PER_TEST_FILE=15

ALLOWLIST_PATH="docs/architecture/complexity-allowlist.tsv"
ALLOWLIST_HEADER=$'category\tpath\tlimit\tactual\treason\ttarget_version\towner'

fail() {
  echo "complexity budget failed: $*" >&2
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
ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

violations=0

line_count() {
  wc -l < "$1" | tr -d ' '
}

source_contains_count() {
  awk 'index($0, "source.contains") { count++ } END { print count + 0 }' "$1"
}

record_violation() {
  local category="$1"
  local path="$2"
  local actual="$3"
  local limit="$4"

  printf '  %s: %s has %s, limit %s\n' "$category" "$path" "$actual" "$limit" >&2
  violations=1
}

valid_category() {
  case "$1" in
    top-level-view|focused-subview|model-reducer|test-helper|test-file|source-contains)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

budget_limit_for_category() {
  case "$1" in
    top-level-view)
      echo "$MAX_TOP_LEVEL_VIEW_LINES"
      ;;
    focused-subview)
      echo "$MAX_FOCUSED_SUBVIEW_LINES"
      ;;
    model-reducer)
      echo "$MAX_MODEL_REDUCER_LINES"
      ;;
    test-helper)
      echo "$MAX_TEST_HELPER_LINES"
      ;;
    test-file)
      echo "$MAX_TEST_FILE_LINES"
      ;;
    source-contains)
      echo "$MAX_SOURCE_CONTAINS_PER_TEST_FILE"
      ;;
    *)
      return 1
      ;;
  esac
}

actual_for_category() {
  local category="$1"
  local path="$2"

  case "$category" in
    source-contains)
      source_contains_count "$path"
      ;;
    *)
      line_count "$path"
      ;;
  esac
}

validate_allowlist_manifest() {
  [[ -f "$ALLOWLIST_PATH" ]] || fail "missing $ALLOWLIST_PATH"

  local header
  IFS= read -r header < "$ALLOWLIST_PATH" || fail "$ALLOWLIST_PATH is empty"
  [[ "$header" == "$ALLOWLIST_HEADER" ]] || fail "$ALLOWLIST_PATH header must be: $ALLOWLIST_HEADER"

  local category
  local manifest_path
  local limit
  local actual
  local reason
  local target_version
  local owner
  local extra
  local expected_limit
  local current_actual
  local line_number=1

  while IFS=$'\t' read -r category manifest_path limit actual reason target_version owner extra; do
    ((line_number += 1))
    [[ -z "$category$manifest_path$limit$actual$reason$target_version$owner${extra:-}" ]] && continue

    [[ -z "${extra:-}" ]] || record_violation "allowlist columns" "$ALLOWLIST_PATH:$line_number" 8 7
    [[ "$category" != "source-contains" ]] || record_violation "source-contains allowlist row" "$ALLOWLIST_PATH:$line_number" "$category" "no source-contains rows"
    valid_category "$category" || record_violation "allowlist category" "$ALLOWLIST_PATH:$line_number" "$category" "known category"
    [[ -n "$manifest_path" ]] || record_violation "allowlist path" "$ALLOWLIST_PATH:$line_number" 0 "non-empty path"
    [[ -f "$manifest_path" ]] || record_violation "allowlist path exists" "$manifest_path" 0 "tracked file"
    [[ -n "$reason" ]] || record_violation "allowlist reason" "$manifest_path" 0 "non-empty reason"
    [[ -n "$target_version" ]] || record_violation "allowlist target_version" "$manifest_path" 0 "non-empty target_version"
    [[ -n "$owner" ]] || record_violation "allowlist owner" "$manifest_path" 0 "non-empty owner"

    if valid_category "$category"; then
      expected_limit="$(budget_limit_for_category "$category")"
      if [[ "$limit" =~ ^[0-9]+$ ]]; then
        [[ "$limit" == "$expected_limit" ]] || record_violation "$category allowlist limit" "$manifest_path" "$limit" "$expected_limit"
      else
        record_violation "$category allowlist limit" "$manifest_path" "$limit" "numeric"
      fi

      if [[ -f "$manifest_path" ]]; then
        current_actual="$(actual_for_category "$category" "$manifest_path")"
        if [[ "$actual" =~ ^[0-9]+$ ]]; then
          [[ "$actual" == "$current_actual" ]] || record_violation "$category allowlist actual" "$manifest_path" "$actual" "$current_actual"
        else
          record_violation "$category allowlist actual" "$manifest_path" "$actual" "numeric"
        fi
      fi
    fi

  done < <(tail -n +2 "$ALLOWLIST_PATH")
}

allow_over_budget_reason() {
  local category="$1"
  local path="$2"

  awk -F '\t' -v category="$category" -v path="$path" '
    NR > 1 && $1 == category && $2 == path {
      print $5
      found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$ALLOWLIST_PATH"
}

check_budget() {
  local category="$1"
  local path="$2"
  local actual="$3"
  local limit="$4"
  local reason

  if (( actual <= limit )); then
    return 0
  fi

  if reason="$(allow_over_budget_reason "$category" "$path")"; then
    [[ -n "$reason" ]] || record_violation "$category allowlist reason" "$path" 0 "non-empty reason"
    return 0
  fi

  record_violation "$category" "$path" "$actual" "$limit"
}

is_test_helper_file() {
  case "$1" in
    Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/*Support.swift|\
    Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeTestFactory.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_swift_file() {
  local path="$1"
  local lines
  local source_contains

  lines="$(line_count "$path")"

  case "$path" in
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*/*/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*/*.swift)
      check_budget "focused-subview" "$path" "$lines" "$MAX_FOCUSED_SUBVIEW_LINES"
      ;;
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/*.swift)
      check_budget "top-level-view" "$path" "$lines" "$MAX_TOP_LEVEL_VIEW_LINES"
      ;;
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/*.swift|\
    Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel*.swift)
      check_budget "model-reducer" "$path" "$lines" "$MAX_MODEL_REDUCER_LINES"
      ;;
  esac

  if [[ "$path" == Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/*.swift ]]; then
    if is_test_helper_file "$path"; then
      check_budget "test-helper" "$path" "$lines" "$MAX_TEST_HELPER_LINES"
    else
      check_budget "test-file" "$path" "$lines" "$MAX_TEST_FILE_LINES"
    fi

    source_contains="$(source_contains_count "$path")"
    check_budget "source-contains" "$path" "$source_contains" "$MAX_SOURCE_CONTAINS_PER_TEST_FILE"
  fi
}

validate_allowlist_manifest
if (( violations != 0 )); then
  fail "allowlist manifest is invalid"
fi

while IFS= read -r path; do
  check_swift_file "$path"
done < <(git ls-files '*.swift')

if (( violations != 0 )); then
  fail "one or more files exceed the post-stable complexity budget"
fi

echo "complexity budget passed ($MODE)"
