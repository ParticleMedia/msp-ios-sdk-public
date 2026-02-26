#!/usr/bin/env bash
# Unit tests for version_commit.sh module
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

# Source version_management.sh first (dependency)
source "$ROOT_DIR/Scripts/release/publish/pods/lib/version_management.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/pods/lib/version_commit.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_VERSION_COMMIT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(ensure_adapter_version_committed commit_adapter_version_updates ensure_mspcore_version_committed)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: dry run mode skips commit operations
test_dry_run_skips() {
    export DRY_RUN="true"
    export ROOT_DIR

    # Should return 0 (success) without doing anything
    if ensure_adapter_version_committed "MSPGoogleAdapter" "1.0.0" 2>/dev/null; then
        test_pass "ensure_adapter_version_committed returns 0 in dry-run mode"
    else
        test_fail "ensure_adapter_version_committed should return 0 in dry-run mode"
    fi

    if ensure_mspcore_version_committed "1.0.0" 2>/dev/null; then
        test_pass "ensure_mspcore_version_committed returns 0 in dry-run mode"
    else
        test_fail "ensure_mspcore_version_committed should return 0 in dry-run mode"
    fi

    unset DRY_RUN
}

# Test: commit_adapter_version_updates handles empty adapter list
test_commit_empty_adapters() {
    export DRY_RUN="true"
    export ROOT_DIR

    if commit_adapter_version_updates "1.0.0" 2>/dev/null; then
        test_pass "commit_adapter_version_updates handles empty adapter list"
    else
        test_fail "commit_adapter_version_updates should return 0 for empty adapter list"
    fi

    unset DRY_RUN
}

# Run tests
echo "Running version_commit.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_dry_run_skips
test_commit_empty_adapters

echo "========================================"
echo "All tests passed!"
