#!/usr/bin/env bash

set -euo pipefail

# Test Case 05: Rollback plan only (no --force)

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Rollback plan only (no destructive actions)"

# Create synthetic state with git flags set
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1" "release/0.0.1"

# Clear mock log
clear_mock_log

# Run rollback without --force
output=$(./Scripts/msp-release.sh rollback --no-ansi 2>&1 || true)

# Assert output contains plan text
assert_contains "$output" "Would delete local git tag" "Rollback plan should mention tag deletion"
assert_contains "$output" "Would delete remote git tag" "Rollback plan should mention remote tag deletion"
assert_contains "$output" "Would delete remote release branch" "Rollback plan should mention branch deletion"
assert_contains "$output" "Would delete GitHub Release" "Rollback plan should mention GitHub Release deletion"

# Assert that no destructive actions were taken (check mock log)
# Note: mock log might not exist if no commands were run
if [[ -f "$MOCK_LOG" ]]; then
    mock_log_not_contains "$MOCK_LOG" "git tag -d" "No tag deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "git push origin :refs/tags" "No remote tag deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "git push origin --delete" "No branch deletion should occur without --force"
    mock_log_not_contains "$MOCK_LOG" "gh release delete" "No GitHub Release deletion should occur without --force"
fi

# Assert state flags are unchanged
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
assert_equals "true" "$tag_created" "tag_created flag should remain true"

branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
assert_equals "true" "$branch_pushed" "release_branch_pushed flag should remain true"

echo "✓ Test passed: Rollback plan only, no destructive actions"

