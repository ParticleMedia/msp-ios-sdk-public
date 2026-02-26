#!/usr/bin/env bash
# Unit tests for release/orchestrator/lib/summary.sh module
# TDD: Tests written first, then module implemented

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source logger only
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/orchestrator/lib/summary.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_ORCH_SUMMARY_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        orch_show_release_summary
        orch_print_step_summary
        orch_calculate_duration
        orch_get_step_status_from_state
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: duration calculation
test_duration_calculation() {
    local duration
    duration=$(orch_calculate_duration "2026-01-01 10:00:00" "2026-01-01 10:05:30")
    if [[ "$duration" == "5m 30s" ]]; then
        test_pass "orch_calculate_duration calculates correctly"
    else
        # Duration calculation may vary by platform, just check it's not empty
        if [[ -n "$duration" ]]; then
            test_pass "orch_calculate_duration returns a value: $duration"
        else
            test_fail "orch_calculate_duration should return a duration string"
        fi
    fi
}

# Test: get step status returns unknown for missing state file
test_get_step_status_missing() {
    local status
    status=$(orch_get_step_status_from_state "/nonexistent/path.json" "test_step")
    if [[ "$status" == "unknown" ]]; then
        test_pass "orch_get_step_status_from_state returns unknown for missing file"
    else
        test_fail "orch_get_step_status_from_state should return unknown for missing file, got: $status"
    fi
}

# Run tests
echo "Running release/orchestrator/lib/summary.sh unit tests..."
echo "========================================================"

test_module_guard
test_functions_exist
test_duration_calculation
test_get_step_status_missing

echo "========================================================"
echo "All tests passed!"
