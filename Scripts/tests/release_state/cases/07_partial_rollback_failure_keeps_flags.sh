#!/usr/bin/env bash

set -euo pipefail

# Test Case 07: Partial rollback failure keeps flags

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Partial rollback failure keeps flags"

# Create synthetic state with git flags set
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1" "release/0.0.1"

# Configure mocks so tag deletion succeeds but branch deletion fails
export MOCK_GIT_FAIL_ON_BRANCH_DELETE=1

# Clear mock log
clear_mock_log

# Run rollback with --force (pipe newline for confirmation)
output=$(printf '\n' | ./Scripts/msp-release.sh rollback --force 2>&1 || true)

# Assert exit code is non-zero (failure)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    echo "ASSERT FAILED: Rollback should exit with non-zero code on partial failure" >&2
    exit 1
fi

# Assert output indicates tag deletion success
assert_contains "$output" "Deleted git tag" "Output should indicate tag deletion success"

# Assert output indicates branch deletion failure
assert_contains "$output" "Failed to delete remote release branch" "Output should indicate branch deletion failure"

# Verify tag deletion occurred
mock_log_contains "git tag -d v0.0.1" "Tag deletion should occur"

# Verify branch deletion was attempted
mock_log_contains "git push origin --delete release/0.0.1" "Branch deletion should be attempted"

# According to current implementation, flags should remain unchanged on partial failure
# (so users can see what was not completed)
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
# Tag deletion succeeded, but overall rollback failed, so flag may or may not be reset
# Check that at least branch_pushed is still true (since branch deletion failed)
branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
assert_equals "true" "$branch_pushed" "release_branch_pushed flag should remain true after branch deletion failure"

# Clean up
unset MOCK_GIT_FAIL_ON_BRANCH_DELETE

echo "✓ Test passed: Partial rollback failure keeps flags for visibility"

