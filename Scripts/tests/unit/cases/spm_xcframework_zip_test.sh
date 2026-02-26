#!/usr/bin/env bash
# Unit tests for release/publish/spm/lib/xcframework_zip.sh module
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
source "$ROOT_DIR/Scripts/release/publish/spm/lib/xcframework_zip.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_SPM_XCFRAMEWORK_ZIP_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        spm_create_deterministic_zip
        spm_compute_zip_checksum
        spm_upload_to_github_release
        spm_probe_zip_url
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: zip file not found returns error
test_checksum_missing_file() {
    local result
    result=$(spm_compute_zip_checksum "/nonexistent/file.zip" 2>/dev/null || echo "error")
    if [[ "$result" == "error" ]] || [[ -z "$result" ]]; then
        test_pass "spm_compute_zip_checksum returns error for missing file"
    else
        test_fail "spm_compute_zip_checksum should return error for missing file"
    fi
}

# Test: config variables exist
test_config_defaults() {
    # These should be defined with default values
    if [[ -n "${SPM_ZIP_DEFAULT_GITHUB_REPO:-}" ]]; then
        test_pass "SPM_ZIP_DEFAULT_GITHUB_REPO has default value"
    else
        test_fail "SPM_ZIP_DEFAULT_GITHUB_REPO should have default value"
    fi
}

# Run tests
echo "Running release/publish/spm/lib/xcframework_zip.sh unit tests..."
echo "========================================================"

test_module_guard
test_functions_exist
test_checksum_missing_file
test_config_defaults

echo "========================================================"
echo "All tests passed!"
