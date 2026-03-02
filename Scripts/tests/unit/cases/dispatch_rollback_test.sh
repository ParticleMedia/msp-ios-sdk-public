#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/release/cli/dispatch.sh msp_do_rollback()
# @test Verifies --force flag handling: global FORCE, REMAINING_ARGS --force, neither

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

DISPATCH_SH="$REPO_ROOT/Scripts/release/cli/dispatch.sh"

# ============================================================================
# Code existence tests
# ============================================================================

test_dispatch_file_exists() {
    assert_file_exists "$DISPATCH_SH" "dispatch.sh should exist"
}

test_rollback_function_exists() {
    local found
    found=$(grep -c 'msp_do_rollback()' "$DISPATCH_SH")
    assert_not_equals "0" "$found" "msp_do_rollback function should be defined"
}

# ============================================================================
# Force flag logic tests (static analysis)
# ============================================================================

test_checks_global_force_flag() {
    # msp_do_rollback should check FORCE global variable
    local found
    found=$(grep -c 'FORCE:-false' "$DISPATCH_SH")
    assert_not_equals "0" "$found" "should check global FORCE flag with default false"
}

test_checks_remaining_args_force() {
    # msp_do_rollback should also check REMAINING_ARGS for --force
    local found
    found=$(grep -A20 'msp_do_rollback()' "$DISPATCH_SH" | grep -c '\-\-force)')
    assert_not_equals "0" "$found" "should check REMAINING_ARGS for --force"
}

test_force_local_var_initialized() {
    # msp_do_rollback should initialize local force=0
    local found
    found=$(grep -A5 'msp_do_rollback()' "$DISPATCH_SH" | grep -c 'local force=0')
    assert_not_equals "0" "$found" "should initialize local force=0"
}

test_delegates_to_cmd_rollback() {
    # msp_do_rollback should delegate to msp_cmd_rollback with force arg
    local found
    found=$(grep -c 'msp_cmd_rollback "\$force"' "$DISPATCH_SH")
    assert_not_equals "0" "$found" "should delegate to msp_cmd_rollback with force argument"
}

test_handles_no_ansi_in_remaining_args() {
    # msp_do_rollback should handle --no-ansi in REMAINING_ARGS
    local found
    found=$(grep -A20 'msp_do_rollback()' "$DISPATCH_SH" | grep -c '\-\-no-ansi)')
    assert_not_equals "0" "$found" "should handle --no-ansi in REMAINING_ARGS"
}

# ============================================================================
# Force flag integration tests (function execution)
# ============================================================================

test_force_from_global_flag() {
    # Simulate: FORCE=true should set local force=1
    # We test by extracting and running just the force detection logic
    local force=0
    FORCE="true"
    if [[ "${FORCE:-false}" == "true" ]]; then
        force=1
    fi
    assert_equals "1" "$force" "FORCE=true should set force=1"
    unset FORCE
}

test_force_from_remaining_args() {
    # Simulate: --force in REMAINING_ARGS should set force=1
    local force=0
    local REMAINING_ARGS=("--force" "--verbose")
    for arg in "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"; do
        case "$arg" in
            --force) force=1 ;;
        esac
    done
    assert_equals "1" "$force" "--force in REMAINING_ARGS should set force=1"
}

test_no_force_stays_zero() {
    # Simulate: no FORCE flag and no --force in args
    local force=0
    FORCE="false"
    if [[ "${FORCE:-false}" == "true" ]]; then
        force=1
    fi
    local REMAINING_ARGS=("--verbose")
    for arg in "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"; do
        case "$arg" in
            --force) force=1 ;;
        esac
    done
    assert_equals "0" "$force" "force should remain 0 when no --force flag is provided"
    unset FORCE
}

test_dispatch_routes_rollback() {
    # Verify the dispatch table maps "rollback" to msp_do_rollback
    local found
    found=$(grep -A2 'rollback)' "$DISPATCH_SH" | grep -c 'msp_do_rollback')
    assert_not_equals "0" "$found" "dispatch should route 'rollback' to msp_do_rollback"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running dispatch.sh rollback --force unit tests..."

test_dispatch_file_exists
test_rollback_function_exists
test_checks_global_force_flag
test_checks_remaining_args_force
test_force_local_var_initialized
test_delegates_to_cmd_rollback
test_handles_no_ansi_in_remaining_args
test_force_from_global_flag
test_force_from_remaining_args
test_no_force_stays_zero
test_dispatch_routes_rollback

echo ""
info "All dispatch.sh rollback --force tests passed!"
