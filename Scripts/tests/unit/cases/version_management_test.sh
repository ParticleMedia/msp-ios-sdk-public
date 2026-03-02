#!/usr/bin/env bash
# Unit tests for version_management.sh module
# Adapter SDK version functions have been removed — only get_module_dir,
# update_mspcore_version, and podspec functions remain.

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

MODULE_FILE="$ROOT_DIR/Scripts/release/publish/pods/lib/version_management.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_VERSION_MANAGEMENT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: retained functions exist
test_retained_functions_exist() {
    local funcs=(get_module_dir update_mspcore_version update_podspec_for_release update_adapter_podspec_dependencies)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: adapter SDK version functions have been removed
test_adapter_functions_removed() {
    local removed_funcs=(load_adapter_sdk_version_config adapter_sdk_version_should_skip resolve_adapter_sdk_version_tool check_adapter_sdk_version update_adapter_sdk_version)
    for fn in "${removed_funcs[@]}"; do
        if grep -vE '^\s*#' "$MODULE_FILE" | grep -q "$fn"; then
            test_fail "$fn should be removed from module (found non-comment reference)"
        else
            test_pass "$fn removed from module"
        fi
    done
}

# Test: ADAPTER_SDK_VERSION_* state variables have been removed
test_adapter_state_variables_removed() {
    if grep -vE '^\s*#' "$MODULE_FILE" | grep -q 'ADAPTER_SDK_VERSION'; then
        test_fail "ADAPTER_SDK_VERSION_* state variables should be removed"
    else
        test_pass "ADAPTER_SDK_VERSION_* state variables removed"
    fi
}

# Test: update_mspcore_version is a no-op (version reads from Config.plist)
test_update_mspcore_version_is_noop() {
    local output
    output=$(update_mspcore_version "1.0.0" 2>&1)

    if [[ "$output" == *"Config.plist"* ]]; then
        test_pass "update_mspcore_version mentions Config.plist (reads from plist now)"
    else
        test_fail "update_mspcore_version should mention Config.plist"
    fi
}

# Test: get_module_dir maps pod names correctly
test_get_module_dir() {
    local result
    result=$(get_module_dir "MSPAmazonAdapter")
    if [[ "$result" == "AmazonAdapter" ]]; then
        test_pass "get_module_dir maps MSPAmazonAdapter to AmazonAdapter"
    else
        test_fail "get_module_dir should map MSPAmazonAdapter to AmazonAdapter, got: $result"
    fi

    result=$(get_module_dir "MSPNovaAdapter")
    if [[ "$result" == "NovaAdapter" ]]; then
        test_pass "get_module_dir maps MSPNovaAdapter to NovaAdapter"
    else
        test_fail "get_module_dir should map MSPNovaAdapter to NovaAdapter, got: $result"
    fi

    result=$(get_module_dir "MSPMolocoAdapter")
    if [[ "$result" == "MolocoAdapter" ]]; then
        test_pass "get_module_dir maps MSPMolocoAdapter to MolocoAdapter"
    else
        test_fail "get_module_dir should map MSPMolocoAdapter to MolocoAdapter, got: $result"
    fi

    result=$(get_module_dir "MSPLiftoffAdapter")
    if [[ "$result" == "LiftoffAdapter" ]]; then
        test_pass "get_module_dir maps MSPLiftoffAdapter to LiftoffAdapter"
    else
        test_fail "get_module_dir should map MSPLiftoffAdapter to LiftoffAdapter, got: $result"
    fi

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
test_retained_functions_exist
test_adapter_functions_removed
test_adapter_state_variables_removed
test_get_module_dir
test_update_mspcore_version_is_noop

echo "========================================"
echo "All tests passed!"
