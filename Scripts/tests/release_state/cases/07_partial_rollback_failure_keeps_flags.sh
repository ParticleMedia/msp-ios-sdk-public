#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---

set -euo pipefail

# Test Case 07: Partial rollback failure keeps flags

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Partial rollback failure keeps flags"

# Create synthetic state with git flags set (required for rollback to execute actions)
# Parameters: repo_root, version, tag_name, release_branch
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1-test" "release/0.0.1"

# Configure mocks so tag deletion succeeds but branch deletion fails
export MOCK_GIT_FAIL_ON_BRANCH_DELETE=1

# Clear mock log
clear_mock_log

# Run rollback with --force (pipe newline for confirmation)
# Capture exit code separately
set +e
printf '\n' | ./Scripts/msp-release.sh rollback --force --no-ansi > "${repo_root}/rollback_output.log" 2>&1
exit_code=$?
set -e

output=$(cat "${repo_root}/rollback_output.log" 2>/dev/null || echo "")

# Assert exit code is non-zero (failure)
if [[ $exit_code -eq 0 ]]; then
    echo "ASSERT FAILED: Rollback should exit with non-zero code on partial failure (exit_code=$exit_code)" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

# Assert output indicates tag deletion success (check for partial match)
if ! echo "$output" | grep -q "Deleted"; then
    echo "ASSERT FAILED: Output should indicate tag deletion success" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

# Assert output indicates branch deletion failure (check for partial match)
if ! echo "$output" | grep -q "Failed"; then
    echo "ASSERT FAILED: Output should indicate branch deletion failure" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

# Verify tag deletion occurred (use partial pattern - mock logs format: [mock_git] tag -d)
mock_log_contains "$MOCK_LOG" "tag -d" "Tag deletion should occur"

# Verify branch deletion was attempted (use partial pattern - mock logs format: [mock_git] push origin --delete)
mock_log_contains "$MOCK_LOG" "push origin --delete" "Branch deletion should be attempted"

# According to current implementation, when rollback has partial failures,
# the git flags are NOT updated (left as-is for visibility).
# This means tag_created remains true even though tag deletion succeeded,
# and release_branch_pushed remains true because branch deletion failed.
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
pr_branch_pushed="$(read_state_field "$repo_root" '.git.pr_branch_pushed')"
assert_equals "true" "$tag_created" "tag_created flag should remain true after partial rollback failure (not updated for visibility)"
assert_equals "true" "$branch_pushed" "release_branch_pushed flag should remain true after branch deletion failure"
assert_equals "true" "$pr_branch_pushed" "pr_branch_pushed flag should remain true after PR branch deletion failure"

# Clean up
unset MOCK_GIT_FAIL_ON_BRANCH_DELETE

echo "✓ Test passed: Partial rollback failure keeps flags for visibility"
