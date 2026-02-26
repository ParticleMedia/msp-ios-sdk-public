#!/usr/bin/env bash
# Unit tests for zip_management.sh module

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
source "$ROOT_DIR/Scripts/release/publish/pods/lib/zip_management.sh"

# Test: get_zip_inputs_for_pod returns paths
test_get_zip_inputs_for_pod() {
    export ROOT_DIR
    local result
    result=$(get_zip_inputs_for_pod "MSPiOSCore")
    
    if [[ "$result" == *"MSPiOSCore.xcframework"* ]]; then
        test_pass "get_zip_inputs_for_pod returns correct path for MSPiOSCore"
    else
        test_fail "get_zip_inputs_for_pod should return MSPiOSCore.xcframework path"
    fi
}

# Test: latest_mtime returns numeric value
test_latest_mtime() {
    local result
    result=$(latest_mtime "$ROOT_DIR/Scripts" 2>/dev/null || echo "")
    
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        test_pass "latest_mtime returns numeric timestamp"
    else
        test_fail "latest_mtime should return numeric timestamp, got: $result"
    fi
}

# Test: zip_needs_refresh returns 0 for missing zip
test_zip_needs_refresh_missing() {
    export ROOT_DIR
    if zip_needs_refresh "NonExistentPod" "99.99.99" 2>/dev/null; then
        test_pass "zip_needs_refresh returns 0 for missing zip"
    else
        test_fail "zip_needs_refresh should return 0 for missing zip"
    fi
}

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_ZIP_MANAGEMENT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: MSPCore zip inputs include Config.plist
test_get_zip_inputs_mspcore_includes_config_plist() {
    export ROOT_DIR
    local result
    result=$(get_zip_inputs_for_pod "MSPCore")

    if [[ "$result" == *"MSPCore.xcframework"* ]]; then
        test_pass "MSPCore zip inputs include MSPCore.xcframework"
    else
        test_fail "MSPCore zip inputs should include MSPCore.xcframework"
    fi

    if [[ "$result" == *"Config.plist"* ]]; then
        test_pass "MSPCore zip inputs include Config.plist"
    else
        test_fail "MSPCore zip inputs should include Config.plist for getMSPVersion()"
    fi
}

# Test: MSPCore zip inputs are separate from default case
test_get_zip_inputs_mspcore_not_default() {
    export ROOT_DIR
    local mspcore_result default_result
    mspcore_result=$(get_zip_inputs_for_pod "MSPCore")
    default_result=$(get_zip_inputs_for_pod "MSPGoogleAdsTypes")

    # MSPCore should have more entries than a default pod (xcframework + Config.plist)
    local mspcore_lines default_lines
    mspcore_lines=$(echo "$mspcore_result" | wc -l | tr -d ' ')
    default_lines=$(echo "$default_result" | wc -l | tr -d ' ')

    if [[ "$mspcore_lines" -gt "$default_lines" ]]; then
        test_pass "MSPCore has more zip inputs than default pods ($mspcore_lines vs $default_lines)"
    else
        test_fail "MSPCore should have more zip inputs than default pods"
    fi
}

# Run tests
echo "Running zip_management.sh unit tests..."
echo "========================================"

test_module_guard
test_get_zip_inputs_for_pod
test_latest_mtime
test_zip_needs_refresh_missing
test_get_zip_inputs_mspcore_includes_config_plist
test_get_zip_inputs_mspcore_not_default

echo "========================================"
echo "All tests passed!"
