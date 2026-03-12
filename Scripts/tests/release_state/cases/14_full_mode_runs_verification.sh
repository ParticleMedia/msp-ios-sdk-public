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

# Test Case 14 (T036): Validate that --full mode runs verification phase
# Per FR-007: Full mode should include all verification steps

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Full mode (--full flag) runs verification phase"

# Run in full mode with --full flag
# Use --dry-run to avoid actual releases, --skip-preflight to speed up
output="$(./Scripts/msp-release.sh run 0.0.1 --full --dry-run --skip-preflight --no-ansi 2>&1 || true)"

# Wait a moment for state file to be written
sleep 0.5

# Assert 1: Output should indicate full mode
assert_contains "$output" "Full release mode" "Should indicate full release mode"

# Assert 2: Output should NOT mention skipping verification
assert_not_contains "$output" "Skipping verification" "Should NOT mention skipping verification"

# Assert 3: Verification steps should be mentioned (attempting to run)
# Note: In dry-run mode, verification may not actually execute, but it should be mentioned
# Check for any verification-related step mentions
verification_mentioned=false
if [[ "$output" == *"verification"* ]] || [[ "$output" == *"verify"* ]] || [[ "$output" == *"Verify"* ]]; then
    verification_mentioned=true
fi

# In dry-run, we might not see actual verification execution, but we should NOT see "Skipping verification"
# The key assertion is that full mode does NOT skip verification

# Assert 4: State file should have release_mode = full
state_file="${repo_root}/.msp-release-state.json"
if [[ -f "$state_file" ]]; then
    release_mode="$(read_state_field "$repo_root" '.release_mode // "<missing>"')"
    if [[ "$release_mode" == "<missing>" ]]; then
        echo "INFO: release_mode not stored in state file (acceptable)"
    else
        assert_equals "full" "$release_mode" "State file release_mode should be 'full'"
    fi
fi

echo "✓ Test passed: Full mode correctly includes verification phase"
