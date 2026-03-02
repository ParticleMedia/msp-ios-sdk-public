#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/testflight/lib/validate.sh
# ============================================================================
# Tests prerequisite validation logic by mocking tool availability
# and environment variables.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

# Stub logging functions
log::info()    { :; }
log::error()   { :; }
log::warn()    { :; }
log::success() { :; }
log::debug()   { :; }

# Exit codes
EXIT_SUCCESS=0
EXIT_VALIDATION_ERROR=3

# ============================================================================
# Test Setup
# ============================================================================

PASSED=0
FAILED=0

pass() {
    local msg="$1"
    echo -e "${_GREEN:-}✓${_NC:-} $msg"
    PASSED=$((PASSED + 1))
}

fail() {
    local msg="$1"
    echo -e "${_RED:-}✗${_NC:-} $msg"
    FAILED=$((FAILED + 1))
}

setup_test_env() {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create a fake workspace
    mkdir -p "$tmpdir/msp-ios-sdk.xcworkspace"
    echo '<?xml version="1.0"?>' > "$tmpdir/msp-ios-sdk.xcworkspace/contents.xcworkspacedata"

    # Create a fake .p8 key file
    echo "fake-key" > "$tmpdir/AuthKey.p8"

    echo "$tmpdir"
}

# ============================================================================
# Test Cases
# ============================================================================

test_module_guard() {
    unset _TF_VALIDATE_SOURCED
    source "$ROOT_DIR/Scripts/testflight/lib/validate.sh"

    if [[ -n "${_TF_VALIDATE_SOURCED:-}" ]]; then
        pass "Module guard variable _TF_VALIDATE_SOURCED is set"
    else
        fail "Module guard variable _TF_VALIDATE_SOURCED not set"
    fi
}

test_validate_passes_with_all_prerequisites() {
    local tmpdir
    tmpdir=$(setup_test_env)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    # Set all required env vars
    export ASC_KEY_ID="test-key-id"
    export ASC_ISSUER_ID="test-issuer-id"
    export ASC_KEY_PATH="$tmpdir/AuthKey.p8"

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "Validation passes when all prerequisites met"
    else
        fail "Validation should pass, got exit code: $exit_code"
    fi

    unset ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
    rm -rf "$tmpdir"
}

test_validate_fails_missing_asc_key_id() {
    local tmpdir
    tmpdir=$(setup_test_env)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    # Unset ASC_KEY_ID, set others
    unset ASC_KEY_ID
    export ASC_ISSUER_ID="test-issuer-id"
    export ASC_KEY_PATH="$tmpdir/AuthKey.p8"

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails when ASC_KEY_ID missing"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    unset ASC_ISSUER_ID ASC_KEY_PATH
    rm -rf "$tmpdir"
}

test_validate_fails_missing_asc_issuer_id() {
    local tmpdir
    tmpdir=$(setup_test_env)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    export ASC_KEY_ID="test-key-id"
    unset ASC_ISSUER_ID
    export ASC_KEY_PATH="$tmpdir/AuthKey.p8"

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails when ASC_ISSUER_ID missing"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    unset ASC_KEY_ID ASC_KEY_PATH
    rm -rf "$tmpdir"
}

test_validate_fails_missing_asc_key_path() {
    local tmpdir
    tmpdir=$(setup_test_env)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    export ASC_KEY_ID="test-key-id"
    export ASC_ISSUER_ID="test-issuer-id"
    unset ASC_KEY_PATH

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails when ASC_KEY_PATH missing"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    unset ASC_KEY_ID ASC_ISSUER_ID
    rm -rf "$tmpdir"
}

test_validate_fails_p8_file_not_found() {
    local tmpdir
    tmpdir=$(setup_test_env)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    export ASC_KEY_ID="test-key-id"
    export ASC_ISSUER_ID="test-issuer-id"
    export ASC_KEY_PATH="$tmpdir/nonexistent.p8"

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails when .p8 file does not exist"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    unset ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
    rm -rf "$tmpdir"
}

test_validate_fails_missing_workspace() {
    local tmpdir
    tmpdir=$(mktemp -d)

    # Create .p8 but NO workspace
    echo "fake-key" > "$tmpdir/AuthKey.p8"

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    export ASC_KEY_ID="test-key-id"
    export ASC_ISSUER_ID="test-issuer-id"
    export ASC_KEY_PATH="$tmpdir/AuthKey.p8"

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails when workspace missing"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    unset ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
    rm -rf "$tmpdir"
}

test_validate_fails_multiple_errors() {
    local tmpdir
    tmpdir=$(mktemp -d)

    unset _TF_VALIDATE_SOURCED
    ROOT_DIR="$tmpdir"
    TF_WORKSPACE="msp-ios-sdk.xcworkspace"

    # Unset all ASC vars
    unset ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH

    source "$SCRIPT_DIR/../../../testflight/lib/validate.sh"

    local exit_code=0
    tf_validate_prerequisites || exit_code=$?

    if [[ $exit_code -eq $EXIT_VALIDATION_ERROR ]]; then
        pass "Validation fails with multiple missing prerequisites"
    else
        fail "Should fail with EXIT_VALIDATION_ERROR ($EXIT_VALIDATION_ERROR), got: $exit_code"
    fi

    rm -rf "$tmpdir"
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running testflight/lib/validate.sh unit tests..."
echo "============================================"

test_module_guard
test_validate_passes_with_all_prerequisites
test_validate_fails_missing_asc_key_id
test_validate_fails_missing_asc_issuer_id
test_validate_fails_missing_asc_key_path
test_validate_fails_p8_file_not_found
test_validate_fails_missing_workspace
test_validate_fails_multiple_errors

echo "============================================"
echo "TestFlight validate tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
