#!/usr/bin/env bash
# Unit tests for distribution_utils.sh module
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
source "$ROOT_DIR/Scripts/release/publish/pods/lib/distribution_utils.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_DISTRIBUTION_UTILS_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(is_binary_distribution get_default_pods_modules get_adapters_list)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: is_binary_distribution returns true for known binary pods
test_is_binary_distribution_true() {
    local binary_pods=(MSPiOSCore MSPSharedLibraries MSPCore MSPNovaAdapter)
    for pod in "${binary_pods[@]}"; do
        if is_binary_distribution "$pod"; then
            test_pass "is_binary_distribution returns true for $pod"
        else
            test_fail "is_binary_distribution should return true for $pod"
        fi
    done
}

# Test: is_binary_distribution returns false for unknown pods
test_is_binary_distribution_false() {
    if is_binary_distribution "UnknownPod"; then
        test_fail "is_binary_distribution should return false for UnknownPod"
    else
        test_pass "is_binary_distribution returns false for UnknownPod"
    fi
}

# Test: get_default_pods_modules returns non-empty list
test_get_default_pods_modules() {
    local result
    result=$(get_default_pods_modules)
    if [[ -n "$result" ]] && [[ "$result" == *"MSPiOSCore"* ]]; then
        test_pass "get_default_pods_modules returns list containing MSPiOSCore"
    else
        test_fail "get_default_pods_modules should return list containing MSPiOSCore"
    fi
}

# Test: get_adapters_list returns adapter names
test_get_adapters_list() {
    local result
    result=$(get_adapters_list)
    if [[ -n "$result" ]] && [[ "$result" == *"Adapter"* ]]; then
        test_pass "get_adapters_list returns adapter names"
    else
        test_fail "get_adapters_list should return adapter names"
    fi
}

# Run tests
echo "Running distribution_utils.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_is_binary_distribution_true
test_is_binary_distribution_false
test_get_default_pods_modules
test_get_adapters_list

echo "========================================"
echo "All tests passed!"
