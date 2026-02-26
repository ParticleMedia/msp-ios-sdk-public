#!/usr/bin/env bash
# Unit tests for release/publish/spm/lib/cdn_verification.sh module
# TDD: Tests written first, then module implemented

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source logger only (skip common.sh to avoid error trap interference)
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/spm/lib/cdn_verification.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_SPM_CDN_VERIFICATION_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        spm_verify_cdn_availability
        spm_verify_checksum_from_cdn
        spm_quick_cdn_check
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: config defaults exist
test_config_defaults() {
    if [[ -n "${SPM_CDN_DEFAULT_GITHUB_REPO:-}" ]]; then
        test_pass "SPM_CDN_DEFAULT_GITHUB_REPO has default value"
    else
        test_fail "SPM_CDN_DEFAULT_GITHUB_REPO should have default value"
    fi

    if [[ -n "${SPM_CDN_DEFAULT_MAX_ATTEMPTS:-}" ]]; then
        test_pass "SPM_CDN_DEFAULT_MAX_ATTEMPTS has default value"
    else
        test_fail "SPM_CDN_DEFAULT_MAX_ATTEMPTS should have default value"
    fi
}

# Test: empty checksums returns success
test_empty_checksums() {
    # Empty array should return 0 (success) - function handles this gracefully
    # Note: Temporarily disable errexit for this test
    set +e
    spm_verify_cdn_availability "v1.0.0" &>/dev/null
    local exit_code=$?
    set -e
    if [[ $exit_code -eq 0 ]]; then
        test_pass "spm_verify_cdn_availability returns success for no checksums"
    else
        test_fail "spm_verify_cdn_availability should return success for no checksums (got exit code $exit_code)"
    fi
}

# Run tests
echo "Running release/publish/spm/lib/cdn_verification.sh unit tests..."
echo "=============================================================="

test_module_guard
test_functions_exist
test_config_defaults
test_empty_checksums

echo "=============================================================="
echo "All tests passed!"
