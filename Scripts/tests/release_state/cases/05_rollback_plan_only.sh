#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 05: Rollback plan only (no --force)

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Rollback plan only (no destructive actions)"

# Create synthetic state with git flags set (for rollback to show plan)
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1" "release/0.0.1"

# Clear mock log
clear_mock_log

# Run rollback without --force
./Scripts/msp-release.sh rollback --no-ansi > "${repo_root}/rollback_output.log" 2>&1 || true
output=$(cat "${repo_root}/rollback_output.log" 2>/dev/null || echo "")

# Assert output contains rollback header (based on actual output)
# Note: Output may contain ANSI codes, so we check for partial matches
if ! echo "$output" | grep -q "MSP Release - Rollback Plan"; then
    echo "ASSERT FAILED: Rollback should show plan header" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

if ! echo "$output" | grep -q "MSP Rollback Plan"; then
    echo "ASSERT FAILED: Rollback should show rollback plan section" >&2
    echo "Output (first 500 chars): ${output:0:500}" >&2
    exit 1
fi

# If git flags are set, it may show "Would delete" messages, but if not set, it shows "No ... recorded"
# We just verify the header exists, not the detailed plan text

# Assert that no destructive actions were taken (check mock log)
# Note: mock log might not exist if no commands were run
if [[ -f "$MOCK_LOG" ]]; then
    mock_log_not_contains "$MOCK_LOG" "git tag -d" "No tag deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "git push origin :refs/tags" "No remote tag deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "git push origin --delete" "No branch deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "gh release delete" "No GitHub Release deletion should occur without --force"
fi

# Assert state flags are unchanged (rollback without --force should not modify state)
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
assert_equals "true" "$tag_created" "tag_created flag should remain true"

branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
assert_equals "true" "$branch_pushed" "release_branch_pushed flag should remain true"

echo "✓ Test passed: Rollback plan only, no destructive actions"

