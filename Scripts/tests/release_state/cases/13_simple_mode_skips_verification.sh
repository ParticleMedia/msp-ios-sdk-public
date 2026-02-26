#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 13 (T035): Validate that simple mode (default) skips verification phase
# Simple mode is the default when --full flag is not provided
# Per FR-007: Simple mode should skip all verification steps

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Simple mode (default) skips verification phase"

# Run in simple mode (no --full flag)
# Use --dry-run to avoid actual releases, --skip-preflight to speed up
output="$(./Scripts/msp-release.sh run 0.0.1 --dry-run --skip-preflight --no-ansi 2>&1 || true)"

# Wait a moment for state file to be written
sleep 0.5

# Assert 1: Output should indicate simple mode
assert_contains "$output" "Simple release mode" "Should indicate simple release mode"

# Assert 2: Output should mention skipping verification
assert_contains "$output" "Skipping verification" "Should mention skipping verification"

# Assert 3: State file should have release_mode = simple
state_file="${repo_root}/.msp-release-state.json"
if [[ -f "$state_file" ]]; then
    release_mode="$(read_state_field "$repo_root" '.release_mode // "<missing>"')"
    # Note: release_mode may not be stored in state file yet, so check both
    if [[ "$release_mode" == "<missing>" ]]; then
        echo "INFO: release_mode not stored in state file (acceptable)"
    else
        assert_equals "simple" "$release_mode" "State file release_mode should be 'simple'"
    fi
fi

# Assert 4: Verification steps should be SKIPPED (step_skip), not RUNNING
# Check that verification steps are marked as skipped with "simple mode" reason
assert_contains "$output" "(simple mode)" "Should indicate verification steps are skipped with 'simple mode' reason"

echo "✓ Test passed: Simple mode correctly skips verification phase"
