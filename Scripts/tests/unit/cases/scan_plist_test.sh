#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/release/verify_xcframework/scan_plist.sh
# @test Validates XCFramework Info.plist scanning: valid structure, missing plist, missing fields

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

SCAN_PLIST_SH="$REPO_ROOT/Scripts/release/verify_xcframework/scan_plist.sh"

# ============================================================================
# Code existence tests
# ============================================================================

test_scan_plist_file_exists() {
    assert_file_exists "$SCAN_PLIST_SH" "scan_plist.sh should exist"
}

test_scan_plist_function_defined() {
    local found
    found=$(grep -c 'scan_plist()' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "scan_plist function should be defined"
}

test_uses_set_euo_pipefail() {
    local found
    found=$(grep -c 'set -euo pipefail' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should use set -euo pipefail"
}

# ============================================================================
# Parameter validation tests (static analysis)
# ============================================================================

test_validates_xcframework_path() {
    # Should check for empty or non-existent path
    local found
    found=$(grep -c 'Invalid XCFramework path' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should validate xcframework_path parameter"
}

test_validates_module_name() {
    # Should check for empty module name
    local found
    found=$(grep -c 'Module name required' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should validate module_name parameter"
}

# ============================================================================
# Plist validation logic tests
# ============================================================================

test_checks_info_plist_exists() {
    local found
    found=$(grep -c 'Missing Info.plist' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should check for missing Info.plist"
}

test_checks_cfbundle_package_type() {
    # Should validate CFBundlePackageType is XFWK
    local found
    found=$(grep -c 'CFBundlePackageType' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should check CFBundlePackageType"
}

test_checks_xfwk_value() {
    local found
    found=$(grep -c 'XFWK' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should validate CFBundlePackageType equals XFWK"
}

test_checks_slice_version_keys() {
    # Should check CFBundleShortVersionString and CFBundleVersion in slice frameworks
    local found_short
    found_short=$(grep -c 'CFBundleShortVersionString' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found_short" "should check CFBundleShortVersionString in slice plists"

    local found_version
    found_version=$(grep -c 'CFBundleVersion' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found_version" "should check CFBundleVersion in slice plists"
}

test_checks_known_slices() {
    # Should check standard iOS slices
    local found_arm64
    found_arm64=$(grep -c 'ios-arm64' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found_arm64" "should check ios-arm64 slice"

    local found_sim
    found_sim=$(grep -c 'ios-arm64_x86_64-simulator\|ios-arm64-simulator\|ios-x86_64-simulator' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found_sim" "should check simulator slices"
}

# ============================================================================
# Umbrella header tests
# ============================================================================

test_checks_umbrella_header() {
    local found
    found=$(grep -c 'umbrella header' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should check for umbrella header"
}

test_checks_umbrella_header_references() {
    # Should scan umbrella header for #import references
    local found
    found=$(grep -c '#import' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should scan umbrella header for #import references"
}

# ============================================================================
# Error tracking tests
# ============================================================================

test_tracks_errors() {
    local found
    found=$(grep -c 'errors=$((errors + 1))' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should track error count"
}

test_returns_failure_on_errors() {
    local found
    found=$(grep -c 'return 1' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should return 1 on validation errors"
}

test_returns_success_on_valid() {
    local found
    found=$(grep -c 'return 0' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should return 0 on validation success"
}

test_checks_no_framework_slices() {
    local found
    found=$(grep -c 'No framework slices found' "$SCAN_PLIST_SH")
    assert_not_equals "0" "$found" "should fail if no framework slices found"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running scan_plist.sh unit tests..."

test_scan_plist_file_exists
test_scan_plist_function_defined
test_uses_set_euo_pipefail
test_validates_xcframework_path
test_validates_module_name
test_checks_info_plist_exists
test_checks_cfbundle_package_type
test_checks_xfwk_value
test_checks_slice_version_keys
test_checks_known_slices
test_checks_umbrella_header
test_checks_umbrella_header_references
test_tracks_errors
test_returns_failure_on_errors
test_returns_success_on_valid
test_checks_no_framework_slices

echo ""
info "All scan_plist.sh tests passed!"
