#!/usr/bin/env bash
# Unit tests for shared/cdn_verify.sh module
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
source "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_SHARED_CDN_VERIFY_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        cdn_wait_for_propagation
        cdn_verify_url
        cdn_verify_urls
        cdn_build_github_release_url
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: URL building
test_url_building() {
    local url
    url=$(cdn_build_github_release_url "v1.0.0" "TestFramework.xcframework.zip" "TestOrg/TestRepo")
    local expected="https://github.com/TestOrg/TestRepo/releases/download/v1.0.0/TestFramework.xcframework.zip"

    if [[ "$url" == "$expected" ]]; then
        test_pass "cdn_build_github_release_url builds correct URL"
    else
        test_fail "cdn_build_github_release_url should return $expected, got: $url"
    fi
}

# Test: default repo URL building
test_default_repo_url() {
    export MSP_GITHUB_REPO="ParticleMedia/msp-ios-sdk-public"
    local url
    url=$(cdn_build_github_release_url "v1.0.0" "Test.zip")

    if [[ "$url" == *"ParticleMedia/msp-ios-sdk-public"* ]]; then
        test_pass "cdn_build_github_release_url uses default repo"
    else
        test_fail "cdn_build_github_release_url should use MSP_GITHUB_REPO"
    fi
}

# Run tests
echo "Running shared/cdn_verify.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_url_building
test_default_repo_url

echo "========================================"
echo "All tests passed!"
