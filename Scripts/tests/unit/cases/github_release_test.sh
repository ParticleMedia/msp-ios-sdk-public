#!/usr/bin/env bash
# ============================================================================
# Unit Tests: Shared GitHub Release Module
# ============================================================================
# Tests for Scripts/lib/shared/github_release.sh
# ============================================================================

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
TEST_NAME="github_release"

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
    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    # Check guard variable is set
    if [[ "${_SHARED_GITHUB_RELEASE_SOURCED:-}" == "1" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Guard variable not set"
        FAILED=$((FAILED + 1))
    fi
}

test_get_repo_default() {
    test_start "Default repo returns ParticleMedia/msp-ios-sdk-public"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    unset MSP_GITHUB_REPO
    local repo
    repo=$(_github_release_get_repo)

    if [[ "$repo" == "ParticleMedia/msp-ios-sdk-public" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Expected ParticleMedia/msp-ios-sdk-public, got: $repo"
        FAILED=$((FAILED + 1))
    fi
}

test_get_repo_custom() {
    test_start "Custom repo from MSP_GITHUB_REPO"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    export MSP_GITHUB_REPO="test/test-repo"
    local repo
    repo=$(_github_release_get_repo)
    unset MSP_GITHUB_REPO

    if [[ "$repo" == "test/test-repo" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Expected test/test-repo, got: $repo"
        FAILED=$((FAILED + 1))
    fi
}

test_generate_notes_contains_version() {
    test_start "Generated notes contain version tag"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    local notes
    notes=$(github_release_generate_notes "1.2.3")

    if echo "$notes" | grep -q "1.2.3"; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Version 1.2.3 not found in generated notes"
        FAILED=$((FAILED + 1))
    fi
}

test_generate_notes_contains_components() {
    test_start "Generated notes contain MSP components"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    local notes
    notes=$(github_release_generate_notes "1.0.0")

    if echo "$notes" | grep -q "MSPCore" && echo "$notes" | grep -q "MSPSharedLibraries"; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "Component names not found in generated notes"
        FAILED=$((FAILED + 1))
    fi
}

test_build_url_format() {
    test_start "Build URL returns correct format"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    unset MSP_GITHUB_REPO
    local url
    url=$(github_release_build_url "1.0.0" "test.zip")

    if [[ "$url" == "https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/1.0.0/test.zip" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "URL format incorrect: $url"
        FAILED=$((FAILED + 1))
    fi
}

test_build_url_custom_repo() {
    test_start "Build URL uses custom repo"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    export MSP_GITHUB_REPO="custom/repo"
    local url
    url=$(github_release_build_url "2.0.0" "asset.zip")
    unset MSP_GITHUB_REPO

    if [[ "$url" == "https://github.com/custom/repo/releases/download/2.0.0/asset.zip" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "URL with custom repo incorrect: $url"
        FAILED=$((FAILED + 1))
    fi
}

test_backward_compat_create_or_verify() {
    test_start "Backward compat: create_or_verify_github_release exists"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    if command -v create_or_verify_github_release &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "create_or_verify_github_release not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_backward_compat_generate_release_notes() {
    test_start "Backward compat: generate_release_notes exists"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    if command -v generate_release_notes &>/dev/null; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "generate_release_notes not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_backward_compat_upload_functions() {
    test_start "Backward compat: upload functions exist"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    local all_exist=true

    if ! command -v upload_zip_to_github &>/dev/null; then
        all_exist=false
    fi

    if ! command -v upload_all_zips_to_github &>/dev/null; then
        all_exist=false
    fi

    if ! command -v prepare_github_release &>/dev/null; then
        all_exist=false
    fi

    if ! command -v probe_zip_url &>/dev/null; then
        all_exist=false
    fi

    if [[ "$all_exist" == "true" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "One or more upload functions not defined"
        FAILED=$((FAILED + 1))
    fi
}

test_unified_functions_exist() {
    test_start "Unified functions exist"

    source "$ROOT_DIR/Scripts/lib/shared/github_release.sh"

    local all_exist=true

    if ! command -v github_release_create_or_verify &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_upload_asset &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_upload_assets &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_probe_url &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_verify_asset &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_prepare &>/dev/null; then
        all_exist=false
    fi

    if ! command -v github_release_ensure_exists &>/dev/null; then
        all_exist=false
    fi

    if [[ "$all_exist" == "true" ]]; then
        test_pass
        PASSED=$((PASSED + 1))
    else
        test_fail "One or more unified functions not defined"
        FAILED=$((FAILED + 1))
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "========================================"
echo "Running GitHub Release Module Tests"
echo "========================================"
echo ""

test_module_guard
test_get_repo_default
test_get_repo_custom
test_generate_notes_contains_version
test_generate_notes_contains_components
test_build_url_format
test_build_url_custom_repo
test_backward_compat_create_or_verify
test_backward_compat_generate_release_notes
test_backward_compat_upload_functions
test_unified_functions_exist

echo ""
echo "========================================"
echo "Test Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
