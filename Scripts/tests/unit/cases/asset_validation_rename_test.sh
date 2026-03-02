#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/lib/asset_validation.sh function rename
# @test Verifies asset_log_verbose exists and asset_asset_log_verbose does not (rename bug check)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

ASSET_SH="$REPO_ROOT/Scripts/lib/asset_validation.sh"

# ============================================================================
# File existence tests
# ============================================================================

test_file_exists() {
    assert_file_exists "$ASSET_SH" "asset_validation.sh should exist"
}

test_uses_set_euo_pipefail() {
    local found
    found=$(grep -c 'set -euo pipefail' "$ASSET_SH")
    assert_not_equals "0" "$found" "should use set -euo pipefail"
}

# ============================================================================
# Rename correctness tests
# ============================================================================

test_asset_log_verbose_exists() {
    # The function should be named asset_log_verbose (not asset_asset_log_verbose)
    local found
    found=$(grep -c '^asset_log_verbose()' "$ASSET_SH")
    assert_not_equals "0" "$found" "asset_log_verbose() function should exist"
}

test_no_double_prefix_function() {
    # Bug check: asset_asset_log_verbose should NOT exist (double-prefix rename bug)
    local found
    found=$(grep -c 'asset_asset_log_verbose' "$ASSET_SH" || true)
    assert_equals "0" "$found" "asset_asset_log_verbose should NOT exist (double-prefix bug)"
}

test_asset_log_info_exists() {
    local found
    found=$(grep -c '^asset_log_info()' "$ASSET_SH")
    assert_not_equals "0" "$found" "asset_log_info() function should exist"
}

test_no_double_prefix_info() {
    local found
    found=$(grep -c 'asset_asset_log_info' "$ASSET_SH" || true)
    assert_equals "0" "$found" "asset_asset_log_info should NOT exist (double-prefix bug)"
}

# ============================================================================
# Function naming consistency tests
# ============================================================================

test_asset_log_verbose_called_correctly() {
    # Verify callers use the correct function name
    local call_count
    call_count=$(grep -c 'asset_log_verbose ' "$ASSET_SH")
    assert_not_equals "0" "$call_count" "asset_log_verbose should be called in the script"
}

test_asset_log_info_called_correctly() {
    local call_count
    call_count=$(grep -c 'asset_log_info ' "$ASSET_SH")
    assert_not_equals "0" "$call_count" "asset_log_info should be called in the script"
}

test_verbose_checks_verbose_flag() {
    # asset_log_verbose should check VERBOSE flag
    local found
    found=$(grep -A3 'asset_log_verbose()' "$ASSET_SH" | grep -c 'VERBOSE')
    assert_not_equals "0" "$found" "asset_log_verbose should check VERBOSE flag"
}

test_verbose_checks_quiet_flag() {
    # asset_log_verbose should also check QUIET flag
    local found
    found=$(grep -A3 'asset_log_verbose()' "$ASSET_SH" | grep -c 'QUIET')
    assert_not_equals "0" "$found" "asset_log_verbose should check QUIET flag"
}

# ============================================================================
# Main function tests
# ============================================================================

test_main_function_exists() {
    local found
    found=$(grep -c '^main()' "$ASSET_SH")
    assert_not_equals "0" "$found" "main() function should exist"
}

test_has_parse_arguments() {
    local found
    found=$(grep -c 'parse_arguments' "$ASSET_SH")
    assert_not_equals "0" "$found" "should have parse_arguments function"
}

test_has_validate_paths() {
    local found
    found=$(grep -c 'validate_paths' "$ASSET_SH")
    assert_not_equals "0" "$found" "should have validate_paths function"
}

test_has_validate_asset_sync() {
    local found
    found=$(grep -c 'validate_asset_sync' "$ASSET_SH")
    assert_not_equals "0" "$found" "should have validate_asset_sync function"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running asset_validation.sh rename unit tests..."

test_file_exists
test_uses_set_euo_pipefail
test_asset_log_verbose_exists
test_no_double_prefix_function
test_asset_log_info_exists
test_no_double_prefix_info
test_asset_log_verbose_called_correctly
test_asset_log_info_called_correctly
test_verbose_checks_verbose_flag
test_verbose_checks_quiet_flag
test_main_function_exists
test_has_parse_arguments
test_has_validate_paths
test_has_validate_asset_sync

echo ""
info "All asset_validation.sh rename tests passed!"
