#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 01: Validate that a run creates a state file and basic step statuses

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Run creates state file"

# Minimal run (version can be arbitrary)
# Skip preflight to avoid heavy checks, focus on state creation
./Scripts/msp-release.sh run 0.0.1 --dry-run --skip-preflight --no-ansi 2>&1 || true

# Wait a moment for state file to be written
sleep 0.5

# Assert state file exists (check both repo_root and current directory)
if [[ ! -f "${repo_root}/.msp-release-state.json" ]] && [[ ! -f ".msp-release-state.json" ]]; then
    echo "ASSERT FAILED: State file should be created" >&2
    echo "Checked: ${repo_root}/.msp-release-state.json" >&2
    echo "Checked: $(pwd)/.msp-release-state.json" >&2
    exit 1
fi

# Use the state file that exists
if [[ -f "${repo_root}/.msp-release-state.json" ]]; then
    state_file="${repo_root}/.msp-release-state.json"
elif [[ -f ".msp-release-state.json" ]]; then
    state_file=".msp-release-state.json"
    repo_root="$(pwd)"
fi

# Check that 'run' step exists and has status "success" (modular.sh completes and marks it as success)
run_status="$(read_state_field "$repo_root" '.steps["run"].status // "<missing>"')"
if [[ "$run_status" == "<missing>" ]]; then
    echo "ASSERT FAILED: Step 'run' should exist in state" >&2
    exit 1
fi
# In test environment, modular.sh completes → run step is marked as "success"
assert_equals "success" "$run_status" "Step 'run' should have status 'success' (modular.sh completed)"

# Check that version is set
version="$(read_state_field "$repo_root" '.version // "<missing>"')"
assert_equals "0.0.1" "$version" "Version should be set to 0.0.1"

# Check that mode is set
mode="$(read_state_field "$repo_root" '.mode // "<missing>"')"
assert_equals "run" "$mode" "Mode should be 'run'"

echo "✓ Test passed: State file created with correct structure"

