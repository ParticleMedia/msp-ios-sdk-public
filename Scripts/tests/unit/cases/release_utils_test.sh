#!/usr/bin/env bash
# Unit tests for release_utils.sh module
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
source "$ROOT_DIR/Scripts/release/publish/pods/lib/release_utils.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_RELEASE_UTILS_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(unified_github_cli_auth_check commit_release_changes ensure_release_workspace rebuild_release_binaries)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: dry run mode skips operations
test_commit_dry_run() {
    export DRY_RUN="true"
    export ROOT_DIR

    if commit_release_changes 2>/dev/null; then
        test_pass "commit_release_changes returns 0 in dry-run mode"
    else
        test_fail "commit_release_changes should return 0 in dry-run mode"
    fi

    unset DRY_RUN
}

# Test: rebuild_release_binaries skips in dry-run mode
test_rebuild_dry_run() {
    export DRY_RUN="true"
    export ROOT_DIR

    if rebuild_release_binaries 2>/dev/null; then
        test_pass "rebuild_release_binaries returns 0 in dry-run mode"
    else
        test_fail "rebuild_release_binaries should return 0 in dry-run mode"
    fi

    unset DRY_RUN
}

# Run tests
echo "Running release_utils.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_commit_dry_run
test_rebuild_dry_run

echo "========================================"
echo "All tests passed!"
