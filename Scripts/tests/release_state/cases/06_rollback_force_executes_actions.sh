#!/usr/bin/env bash

set -euo pipefail

# Test Case 06: Rollback --force executes actions

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Rollback --force executes actions"

# Create synthetic state with git flags set
create_synthetic_state "$repo_root" "0.0.1" "v0.0.1" "release/0.0.1"

# Clear mock log
clear_mock_log

# Run rollback with --force (pipe newline for confirmation)
output=$(printf '\n' | ./Scripts/msp-release.sh rollback --force --no-ansi 2>&1 || true)

# Assert that destructive actions were taken (check mock log)
mock_log_contains "$MOCK_LOG" "git tag -d v0.0.1" "Tag deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "git push origin :refs/tags/v0.0.1" "Remote tag deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "git push origin --delete release/0.0.1" "Branch deletion should occur with --force"
mock_log_contains "$MOCK_LOG" "gh release delete v0.0.1" "GitHub Release deletion should occur with --force"

# Assert state flags have been reset
tag_created="$(read_state_field "$repo_root" '.git.tag_created')"
assert_equals "false" "$tag_created" "tag_created flag should be reset to false"

tag_name="$(read_state_field "$repo_root" '.git.tag_name')"
assert_equals "null" "$tag_name" "tag_name should be reset to null"

branch_pushed="$(read_state_field "$repo_root" '.git.release_branch_pushed')"
assert_equals "false" "$branch_pushed" "release_branch_pushed flag should be reset to false"

gh_release_created="$(read_state_field "$repo_root" '.git.github_release_created')"
assert_equals "false" "$gh_release_created" "github_release_created flag should be reset to false"

echo "✓ Test passed: Rollback --force executes actions and resets flags"

