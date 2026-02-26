#!/usr/bin/env bash
# Unit tests for shared/input_validation.sh module
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

# Mock git commands for testing
git() {
    case "$1" in
        branch)
            echo "main"
            ;;
        rev-parse)
            if [[ "$2" == "--abbrev-ref" ]]; then
                echo "feature/test"
            else
                echo "/tmp/test-repo"
            fi
            ;;
        *)
            command git "$@"
            ;;
    esac
}
export -f git

# Source module under test
source "$ROOT_DIR/Scripts/lib/shared/input_validation.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_SHARED_INPUT_VALIDATION_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        shared_parse_common_args
        shared_validate_version
        shared_validate_branch
        shared_get_release_branch
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: version validation
test_version_validation() {
    # Valid versions
    if shared_validate_version "1.0.0"; then
        test_pass "shared_validate_version accepts 1.0.0"
    else
        test_fail "shared_validate_version should accept 1.0.0"
    fi

    if shared_validate_version "0.0.2-migration-spm"; then
        test_pass "shared_validate_version accepts 0.0.2-migration-spm"
    else
        test_fail "shared_validate_version should accept 0.0.2-migration-spm"
    fi

    # Invalid versions (empty)
    if ! shared_validate_version ""; then
        test_pass "shared_validate_version rejects empty version"
    else
        test_fail "shared_validate_version should reject empty version"
    fi
}

# Test: get release branch
test_get_release_branch() {
    local branch
    branch=$(shared_get_release_branch "1.0.0")
    if [[ "$branch" == "release/1.0.0" ]]; then
        test_pass "shared_get_release_branch returns correct branch"
    else
        test_fail "shared_get_release_branch should return release/1.0.0, got: $branch"
    fi
}

# Run tests
echo "Running shared/input_validation.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_version_validation
test_get_release_branch

echo "========================================"
echo "All tests passed!"
