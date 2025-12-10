#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---

set -euo pipefail

# Test Case 06: Rollback --force executes actions

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Rollback --force executes actions"

# Create synthetic state with git flags set (required for rollback to execute actions)
# Parameters: repo_root, version, tag_name, release_branch
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1-test" "release/0.0.1"

# Clear mock log
clear_mock_log

# Run rollback with --force (pipe newline for confirmation)
output=$(printf '\n' | ./Scripts/msp-release.sh rollback --force --no-ansi 2>&1 || true)

# Assert that destructive actions were taken (check mock log)
# Mock git logs format: [mock_git] tag -d <tag>, so match "tag -d" not "git tag -d"
mock_log_contains "$MOCK_LOG" "tag -d" "Tag deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "push origin :refs/tags" "Remote tag deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "push origin --delete" "Branch deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "gh release delete" "GitHub Release deletion should occur with --force"

# Assert state flags have been reset (rollback --force should reset git flags)
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
assert_equals "false" "$tag_created" "tag_created flag should be reset to false"

tag_name="$(read_state_field "$repo_root" '.git.tag_name')"
assert_equals "null" "$tag_name" "tag_name should be reset to null"

branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
assert_equals "false" "$branch_pushed" "release_branch_pushed flag should be reset to false"

gh_release_created="$(read_state_field "$repo_root" '.git.github_release_created')"
assert_equals "false" "$gh_release_created" "github_release_created flag should be reset to false"

echo "✓ Test passed: Rollback --force executes actions and resets flags"

