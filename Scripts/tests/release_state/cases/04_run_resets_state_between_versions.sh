#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---

set -euo pipefail

# Test Case 04: Run resets state between versions

repo_root="$(pwd)"

# Source helpers
# shellcheck source=Scripts/tests/release_state/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

echo "Test: Run resets state between versions"

# First run with version 0.0.1
./Scripts/msp-release.sh run 0.0.1 --dry-run --skip-preflight --no-ansi 2>&1 || true

# Wait for state file to be written
sleep 0.5

# Find state file
if [[ -f "${repo_root}/.msp-release-state.json" ]]; then
    state_file="${repo_root}/.msp-release-state.json"
elif [[ -f ".msp-release-state.json" ]]; then
    state_file=".msp-release-state.json"
    repo_root="$(pwd)"
else
    echo "ASSERT FAILED: State file not found after first run" >&2
    exit 1
fi

# Verify version is 0.0.1
version1="$(read_state_field "$repo_root" '.version')"
assert_equals "0.0.1" "$version1" "First run should set version to 0.0.1"

# Verify run step status is "success" (modular.sh completes and marks it as success)
run_status1="$(read_state_field "$repo_root" '.steps["run"].status // "<missing>"')"
assert_equals "success" "$run_status1" "First run should have status 'success' (modular.sh completed)"

# Get the run_id from first run
run_id1="$(read_state_field "$repo_root" '.run_id')"

# Second run with version 0.0.2
./Scripts/msp-release.sh run 0.0.2 --dry-run --skip-preflight --no-ansi 2>&1 || true

# Wait for state file to be updated
sleep 0.5

# Verify version is now 0.0.2
version2="$(read_state_field "$repo_root" '.version')"
assert_equals "0.0.2" "$version2" "Second run should set version to 0.0.2"

# Verify run step status is reset to "success" (modular.sh completes and marks it as success)
run_status2="$(read_state_field "$repo_root" '.steps["run"].status // "<missing>"')"
assert_equals "success" "$run_status2" "Second run should have status 'success' (modular.sh completed)"

# Verify run_id changed (indicating a new run)
run_id2="$(read_state_field "$repo_root" '.run_id')"
if [[ "$run_id1" == "$run_id2" ]]; then
    echo "ASSERT FAILED: run_id should change between runs" >&2
    exit 1
fi

# Verify release_branch is updated
release_branch="$(read_state_field "$repo_root" '.release_branch')"
assert_contains "$release_branch" "0.0.2" "Release branch should contain new version"

echo "✓ Test passed: Run resets state between versions"

