#!/usr/bin/env bash
# Unit tests for input_validation.sh module
# TDD: Tests written first, then module implemented

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source required modules
source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/pods/lib/input_validation.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_INPUT_VALIDATION_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(parse_arguments show_help validate_inputs check_release_branch)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: validate_inputs sets release branch when not provided
test_validate_sets_release_branch() {
    export VERSION="1.0.0"
    export DRY_RUN="true"
    unset RELEASE_BRANCH 2>/dev/null || true
    RELEASE_BRANCH=""

    # Run validate_inputs (should set RELEASE_BRANCH)
    validate_inputs 2>/dev/null || true

    if [[ "$RELEASE_BRANCH" == "release/1.0.0" ]]; then
        test_pass "validate_inputs sets RELEASE_BRANCH when not provided"
    else
        test_fail "validate_inputs should set RELEASE_BRANCH to release/VERSION"
    fi

    unset VERSION RELEASE_BRANCH
}

# Test: check_release_branch skips in dry-run mode
test_check_release_branch_dry_run() {
    export DRY_RUN="true"
    export RELEASE_BRANCH="release/test"

    if check_release_branch 2>/dev/null; then
        test_pass "check_release_branch returns 0 in dry-run mode"
    else
        test_fail "check_release_branch should return 0 in dry-run mode"
    fi

    unset DRY_RUN RELEASE_BRANCH
}

# Test: parse_arguments handles --dry-run flag
test_parse_dry_run_flag() {
    DRY_RUN=""
    parse_arguments --dry-run

    if [[ "$DRY_RUN" == "true" ]]; then
        test_pass "parse_arguments handles --dry-run flag"
    else
        test_fail "parse_arguments should set DRY_RUN=true for --dry-run flag"
    fi

    unset DRY_RUN
}

# Test: parse_arguments handles --verbose flag
test_parse_verbose_flag() {
    VERBOSE=""
    parse_arguments --verbose

    if [[ "$VERBOSE" == "true" ]]; then
        test_pass "parse_arguments handles --verbose flag"
    else
        test_fail "parse_arguments should set VERBOSE=true for --verbose flag"
    fi

    unset VERBOSE
}

# Run tests
echo "Running input_validation.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_validate_sets_release_branch
test_check_release_branch_dry_run
test_parse_dry_run_flag
test_parse_verbose_flag

echo "========================================"
echo "All tests passed!"
