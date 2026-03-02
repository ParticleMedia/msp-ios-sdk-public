#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/release/verify_xcframework/scan_swiftmodules.sh
# @test Validates Swift module scanning: valid/missing .swiftinterface files

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

SCAN_SM_SH="$REPO_ROOT/Scripts/release/verify_xcframework/scan_swiftmodules.sh"

# ============================================================================
# Code existence tests
# ============================================================================

test_file_exists() {
    assert_file_exists "$SCAN_SM_SH" "scan_swiftmodules.sh should exist"
}

test_function_defined() {
    local found
    found=$(grep -c 'scan_swiftmodules()' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "scan_swiftmodules function should be defined"
}

test_uses_set_euo_pipefail() {
    local found
    found=$(grep -c 'set -euo pipefail' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should use set -euo pipefail"
}

# ============================================================================
# Parameter validation tests
# ============================================================================

test_validates_xcframework_path() {
    local found
    found=$(grep -c 'Invalid XCFramework path' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should validate xcframework_path parameter"
}

test_validates_module_name() {
    local found
    found=$(grep -c 'Module name required' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should validate module_name parameter"
}

# ============================================================================
# Swift module scanning logic tests
# ============================================================================

test_checks_swiftinterface_files() {
    local found
    found=$(grep -c '\.swiftinterface' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should check for .swiftinterface files"
}

test_checks_swiftmodule_files() {
    local found
    found=$(grep -c '\.swiftmodule' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should check for .swiftmodule files"
}

test_checks_known_slices() {
    local found_arm64
    found_arm64=$(grep -c 'ios-arm64' "$SCAN_SM_SH")
    assert_not_equals "0" "$found_arm64" "should check ios-arm64 slice"

    local found_sim
    found_sim=$(grep -c 'ios-arm64_x86_64-simulator\|ios-arm64-simulator\|ios-x86_64-simulator' "$SCAN_SM_SH")
    assert_not_equals "0" "$found_sim" "should check simulator slices"
}

test_checks_arch_specific_swiftmodule() {
    # Should check for architecture-specific .swiftmodule files
    local found_arm64
    found_arm64=$(grep -c 'arm64-apple-ios\.swiftmodule' "$SCAN_SM_SH")
    assert_not_equals "0" "$found_arm64" "should check for arm64-apple-ios.swiftmodule"

    local found_x86
    found_x86=$(grep -c 'x86_64-apple-ios-simulator\.swiftmodule' "$SCAN_SM_SH")
    assert_not_equals "0" "$found_x86" "should check for x86_64-apple-ios-simulator.swiftmodule"
}

test_tracks_missing_files() {
    local found
    found=$(grep -c 'missing_files=$((missing_files + 1))' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should track missing file count"
}

test_tracks_scanned_module_dirs() {
    local found
    found=$(grep -c 'scanned_module_dirs' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should track scanned module directory count"
}

# ============================================================================
# Return code tests
# ============================================================================

test_returns_failure_on_missing_interfaces() {
    local found
    found=$(grep -c 'Missing critical Swift module files' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should report missing critical Swift module files"
}

test_returns_success_on_valid() {
    local found
    found=$(grep -c 'Swift module scan passed' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should report scan passed on success"
}

test_warns_missing_swiftmodule() {
    # Missing .swiftmodule should be a warning, not an error (interface-only modules)
    local found
    found=$(grep -c 'may be acceptable for interface-only modules' "$SCAN_SM_SH")
    assert_not_equals "0" "$found" "should warn (not error) for missing .swiftmodule"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running scan_swiftmodules.sh unit tests..."

test_file_exists
test_function_defined
test_uses_set_euo_pipefail
test_validates_xcframework_path
test_validates_module_name
test_checks_swiftinterface_files
test_checks_swiftmodule_files
test_checks_known_slices
test_checks_arch_specific_swiftmodule
test_tracks_missing_files
test_tracks_scanned_module_dirs
test_returns_failure_on_missing_interfaces
test_returns_success_on_valid
test_warns_missing_swiftmodule

echo ""
info "All scan_swiftmodules.sh tests passed!"
