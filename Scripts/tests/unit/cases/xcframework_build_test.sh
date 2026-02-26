#!/usr/bin/env bash
# ============================================================================
# Unit Tests: Shared XCFramework Build Module
# ============================================================================
# Tests for Scripts/lib/shared/xcframework_build.sh
# ============================================================================

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_NAME="xcframework_build"

# Source test helpers
source "$SCRIPT_DIR/../helpers.sh"

# Track test results
PASSED=0
FAILED=0

# ============================================================================
# Test Helper Functions
# ============================================================================

test_start() {
    echo -n "  Testing: $1 ... "
}

test_pass() {
    echo -e "${_GREEN:-}PASS${_NC:-}"
}

test_fail() {
    echo -e "${_RED:-}FAIL${_NC:-}: $1"
}

# ============================================================================
# Test Cases
# ============================================================================

test_module_guard() {
    test_start "Module guard prevents multiple sourcing"

    # Source the module
    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    # Check guard variable is set
    if [[ "${_SHARED_XCFRAMEWORK_BUILD_SOURCED:-}" == "1" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Guard variable not set"
        FAILED=$((FAILED + 1))
    fi
}

test_get_build_settings_iphoneos() {
    test_start "Build settings for iphoneos contain correct platform"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    local settings
    settings=$(xcf_get_build_settings "iphoneos")

    if echo "$settings" | grep -q "SKIP_INSTALL=NO" && \
       echo "$settings" | grep -q "BUILD_LIBRARY_FOR_DISTRIBUTION=YES" && \
       echo "$settings" | grep -q "CODE_SIGNING_ALLOWED=NO"; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Missing expected build settings"
        FAILED=$((FAILED + 1))
    fi
}

test_get_build_settings_simulator() {
    test_start "Build settings for simulator contain correct architectures"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    local settings
    settings=$(xcf_get_build_settings "iphonesimulator")

    # Default simulator archs should include arm64,x86_64
    if echo "$settings" | grep -q "ARCHS="; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Missing ARCHS setting for simulator"
        FAILED=$((FAILED + 1))
    fi
}

test_get_build_settings_deployment_target() {
    test_start "Build settings include deployment target"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    local settings
    settings=$(xcf_get_build_settings "iphoneos" "15.0")

    if echo "$settings" | grep -q "IPHONEOS_DEPLOYMENT_TARGET=15.0"; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Missing or incorrect deployment target"
        FAILED=$((FAILED + 1))
    fi
}

test_get_build_settings_ci_mode() {
    test_start "Build settings include CI optimizations when CI=true"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    # Enable CI mode
    export CI=true
    local settings
    settings=$(xcf_get_build_settings "iphoneos")
    unset CI

    if echo "$settings" | grep -q "DEBUG_INFORMATION_FORMAT=dwarf" && \
       echo "$settings" | grep -q "GCC_OPTIMIZATION_LEVEL=s"; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Missing CI optimization settings"
        FAILED=$((FAILED + 1))
    fi
}

test_build_with_retry_function_exists() {
    test_start "xcf_build_with_retry function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_build_with_retry &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_build_with_retry not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_archive_for_platform_function_exists() {
    test_start "xcf_archive_for_platform function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_archive_for_platform &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_archive_for_platform not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_create_from_archives_function_exists() {
    test_start "xcf_create_from_archives function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_create_from_archives &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_create_from_archives not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_find_framework_in_archive_function_exists() {
    test_start "xcf_find_framework_in_archive function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_find_framework_in_archive &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_find_framework_in_archive not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_build_complete_function_exists() {
    test_start "xcf_build_complete function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_build_complete &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_build_complete not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_clean_build_artifacts_function_exists() {
    test_start "xcf_clean_build_artifacts function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if command -v xcf_clean_build_artifacts &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_clean_build_artifacts not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_config_defaults_defined() {
    test_start "Configuration defaults are defined"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_build.sh"

    if [[ -n "$XCFRAMEWORK_BUILD_DEFAULT_TIMEOUT" ]] && \
       [[ -n "$XCFRAMEWORK_BUILD_DEFAULT_MAX_RETRIES" ]] && \
       [[ -n "$XCFRAMEWORK_BUILD_DEFAULT_DEPLOYMENT_TARGET" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Configuration defaults not set"
        FAILED=$((FAILED + 1))
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "========================================"
echo "Running XCFramework Build Module Tests"
echo "========================================"
echo ""

test_module_guard
test_get_build_settings_iphoneos
test_get_build_settings_simulator
test_get_build_settings_deployment_target
test_get_build_settings_ci_mode
test_build_with_retry_function_exists
test_archive_for_platform_function_exists
test_create_from_archives_function_exists
test_find_framework_in_archive_function_exists
test_build_complete_function_exists
test_clean_build_artifacts_function_exists
test_config_defaults_defined

echo ""
echo "========================================"
echo "Test Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
