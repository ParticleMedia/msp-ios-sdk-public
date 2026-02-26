#!/usr/bin/env bash
# ============================================================================
# Unit Tests: Shared XCFramework Validation Module
# ============================================================================
# Tests for Scripts/lib/shared/xcframework_validate.sh
# ============================================================================

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_NAME="xcframework_validate"

# Source test helpers
source "$SCRIPT_DIR/../helpers.sh"

# Track test results
PASSED=0
FAILED=0

# Test temp directory
TEST_TMP="${TMPDIR:-/tmp}/xcf_validate_test_$$"

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

setup_test_xcframework() {
    # Create a mock XCFramework structure for testing
    local name="$1"
    local xcf_path="$TEST_TMP/${name}.xcframework"

    mkdir -p "$xcf_path/ios-arm64/${name}.framework/Modules"
    mkdir -p "$xcf_path/ios-arm64_x86_64-simulator/${name}.framework/Modules"

    # Create Info.plist
    cat > "$xcf_path/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
</dict>
</plist>
EOF

    # Create module.modulemap
    echo "framework module $name {}" > "$xcf_path/ios-arm64/${name}.framework/Modules/module.modulemap"
    echo "framework module $name {}" > "$xcf_path/ios-arm64_x86_64-simulator/${name}.framework/Modules/module.modulemap"

    echo "$xcf_path"
}

cleanup_test_files() {
    rm -rf "$TEST_TMP"
}

# ============================================================================
# Test Cases
# ============================================================================

test_module_guard() {
    test_start "Module guard prevents multiple sourcing"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if [[ "${_SHARED_XCFRAMEWORK_VALIDATE_SOURCED:-}" == "1" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Guard variable not set"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_exists_function_exists() {
    test_start "xcf_validate_exists function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_exists &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_exists not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_exists_returns_success_for_existing() {
    test_start "xcf_validate_exists returns 0 for existing path"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"
    mkdir -p "$TEST_TMP"

    local xcf_path
    xcf_path=$(setup_test_xcframework "TestFramework")

    if xcf_validate_exists "$xcf_path" "TEST" 2>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Should return 0 for existing XCFramework"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_exists_returns_failure_for_missing() {
    test_start "xcf_validate_exists returns 1 for missing path"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if xcf_validate_exists "/nonexistent/path.xcframework" "TEST" 2>/dev/null; then
        test_fail "Should return 1 for missing XCFramework"
        FAILED=$((FAILED + 1))
    else
        test_pass
        PASSED=$((PASSED + 1))
    fi
}

test_validate_structure_function_exists() {
    test_start "xcf_validate_structure function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_structure &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_structure not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_structure_validates_valid_xcframework() {
    test_start "xcf_validate_structure passes for valid XCFramework"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"
    mkdir -p "$TEST_TMP"

    local xcf_path
    xcf_path=$(setup_test_xcframework "ValidFramework")

    if xcf_validate_structure "$xcf_path" "TEST" 2>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Should pass for valid XCFramework"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_content_function_exists() {
    test_start "xcf_validate_content function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_content &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_content not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_full_function_exists() {
    test_start "xcf_validate_full function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_full &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_full not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_slices_function_exists() {
    test_start "xcf_validate_slices function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_slices &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_slices not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_modulemap_function_exists() {
    test_start "xcf_validate_modulemap function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_modulemap &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_modulemap not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_no_hardcoded_paths_function_exists() {
    test_start "xcf_validate_no_hardcoded_paths function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_no_hardcoded_paths &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_no_hardcoded_paths not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_validate_batch_function_exists() {
    test_start "xcf_validate_batch function exists"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if command -v xcf_validate_batch &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "xcf_validate_batch not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_config_defaults_defined() {
    test_start "Configuration defaults are defined"

    source "$ROOT_DIR/Scripts/lib/shared/xcframework_validate.sh"

    if [[ -n "$XCFRAMEWORK_VALIDATE_DEFAULT_DEVICE_SLICE" ]] && \
       [[ -n "$XCFRAMEWORK_VALIDATE_DEFAULT_SIMULATOR_SLICE" ]]; then
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
echo "Running XCFramework Validate Module Tests"
echo "========================================"
echo ""

# Setup
mkdir -p "$TEST_TMP"
trap cleanup_test_files EXIT

test_module_guard
test_validate_exists_function_exists
test_validate_exists_returns_success_for_existing
test_validate_exists_returns_failure_for_missing
test_validate_structure_function_exists
test_validate_structure_validates_valid_xcframework
test_validate_content_function_exists
test_validate_full_function_exists
test_validate_slices_function_exists
test_validate_modulemap_function_exists
test_validate_no_hardcoded_paths_function_exists
test_validate_batch_function_exists
test_config_defaults_defined

echo ""
echo "========================================"
echo "Test Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
