#!/usr/bin/env bash

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

# Assert state file exists
assert_file_exists "${repo_root}/.msp-release-state.json" "State file should be created"

# Check that 'run' step exists and has a status
run_status="$(read_state_field "$repo_root" '.steps["run"].status // "<missing>"')"
if [[ "$run_status" == "<missing>" ]]; then
    echo "ASSERT FAILED: Step 'run' should exist in state" >&2
    exit 1
fi

# Check that version is set
version="$(read_state_field "$repo_root" '.version // "<missing>"')"
assert_equals "0.0.1" "$version" "Version should be set to 0.0.1"

# Check that mode is set
mode="$(read_state_field "$repo_root" '.mode // "<missing>"')"
assert_equals "run" "$mode" "Mode should be 'run'"

echo "✓ Test passed: State file created with correct structure"

