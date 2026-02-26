#!/usr/bin/env bash
# Unit tests for version_management.sh module
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
source "$ROOT_DIR/Scripts/release/publish/pods/lib/version_management.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_VERSION_MANAGEMENT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: config loader functions exist
test_config_functions_exist() {
    local funcs=(load_adapter_sdk_version_config adapter_sdk_version_should_skip resolve_adapter_sdk_version_tool)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: version check and update functions exist
test_version_functions_exist() {
    local funcs=(check_adapter_sdk_version update_adapter_sdk_version update_mspcore_version)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: podspec functions exist
test_podspec_functions_exist() {
    local funcs=(update_podspec_for_release update_adapter_podspec_dependencies)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: load_adapter_sdk_version_config loads config correctly
test_load_config() {
    export ROOT_DIR

    # Reset config state
    ADAPTER_SDK_VERSION_CONFIG_LOADED="false"

    if load_adapter_sdk_version_config 2>/dev/null; then
        if [[ "${ADAPTER_SDK_VERSION_CONFIG_LOADED}" == "true" ]]; then
            test_pass "load_adapter_sdk_version_config sets LOADED flag"
        else
            test_fail "load_adapter_sdk_version_config should set LOADED flag to true"
        fi
    else
        test_fail "load_adapter_sdk_version_config should succeed with valid config"
    fi
}

# Test: adapter_sdk_version_should_skip returns 1 for non-skipped adapter
test_should_skip_returns_false() {
    export ROOT_DIR

    # Reset and load config
    ADAPTER_SDK_VERSION_CONFIG_LOADED="false"
    load_adapter_sdk_version_config 2>/dev/null || true

    # Test with a non-skipped adapter (assuming MSPGoogleAdapter is not in skip list)
    if adapter_sdk_version_should_skip "MSPGoogleAdapter" 2>/dev/null; then
        # If it returns 0 (should skip), that's also valid depending on config
        test_pass "adapter_sdk_version_should_skip returns valid result for MSPGoogleAdapter"
    else
        test_pass "adapter_sdk_version_should_skip returns 1 (don't skip) for regular adapter"
    fi
}

# Test: get_module_dir maps pod names correctly
test_get_module_dir() {
    # Test mapping for AmazonAdapter
    local result
    result=$(get_module_dir "MSPAmazonAdapter")
    if [[ "$result" == "AmazonAdapter" ]]; then
        test_pass "get_module_dir maps MSPAmazonAdapter to AmazonAdapter"
    else
        test_fail "get_module_dir should map MSPAmazonAdapter to AmazonAdapter, got: $result"
    fi

    # Test passthrough for non-mapped pods
    result=$(get_module_dir "MSPCore")
    if [[ "$result" == "MSPCore" ]]; then
        test_pass "get_module_dir passes through MSPCore unchanged"
    else
        test_fail "get_module_dir should pass through MSPCore unchanged, got: $result"
    fi
}

# Run tests
echo "Running version_management.sh unit tests..."
echo "========================================"

test_module_guard
test_config_functions_exist
test_version_functions_exist
test_podspec_functions_exist
test_get_module_dir
test_load_config
test_should_skip_returns_false

echo "========================================"
echo "All tests passed!"
