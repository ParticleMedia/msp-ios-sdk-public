#!/usr/bin/env bash
# Unit tests for lib/xcodegen.sh module
# R028: XcodeGen operations unification

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source logger only
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/lib/xcodegen.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_XCODEGEN_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(
        xcodegen_ensure_installed
        xcodegen_generate
        xcodegen_validate_output
        xcodegen_generate_and_validate
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: ensure installed checks for xcodegen
test_ensure_installed() {
    if command -v xcodegen &>/dev/null; then
        if xcodegen_ensure_installed; then
            test_pass "xcodegen_ensure_installed returns 0 when xcodegen exists"
        else
            test_fail "xcodegen_ensure_installed should return 0 when xcodegen exists"
        fi
    else
        if ! xcodegen_ensure_installed 2>/dev/null; then
            test_pass "xcodegen_ensure_installed returns 1 when xcodegen missing"
        else
            test_fail "xcodegen_ensure_installed should return 1 when xcodegen missing"
        fi
    fi
}

# Test: generate fails on missing spec
test_generate_missing_spec() {
    if ! xcodegen_generate "/nonexistent/project.yml" 2>/dev/null; then
        test_pass "xcodegen_generate fails on missing spec file"
    else
        test_fail "xcodegen_generate should fail on missing spec file"
    fi
}

# Test: validate output fails on missing xcodeproj
test_validate_missing_xcodeproj() {
    if ! xcodegen_validate_output "/nonexistent/Project.xcodeproj" 2>/dev/null; then
        test_pass "xcodegen_validate_output fails on missing xcodeproj"
    else
        test_fail "xcodegen_validate_output should fail on missing xcodeproj"
    fi
}

# Test: validate output succeeds on valid xcodeproj
test_validate_valid_xcodeproj() {
    # Find a real xcodeproj in the project
    local xcodeproj
    xcodeproj=$(find "$ROOT_DIR" -name "*.xcodeproj" -type d 2>/dev/null | head -1)
    
    if [[ -n "$xcodeproj" ]] && [[ -f "$xcodeproj/project.pbxproj" ]]; then
        if xcodegen_validate_output "$xcodeproj"; then
            test_pass "xcodegen_validate_output succeeds on valid xcodeproj"
        else
            test_fail "xcodegen_validate_output should succeed on valid xcodeproj"
        fi
    else
        test_pass "xcodegen_validate_output (skipped - no xcodeproj found)"
    fi
}

# Run tests
echo "Running lib/xcodegen.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_ensure_installed
test_generate_missing_spec
test_validate_missing_xcodeproj
test_validate_valid_xcodeproj

echo "========================================"
echo "All tests passed!"
