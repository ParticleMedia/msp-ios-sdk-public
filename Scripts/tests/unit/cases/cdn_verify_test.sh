#!/usr/bin/env bash
# Unit tests for cdn_verify.sh module

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
# Note: cdn_verify.sh was consolidated into Scripts/lib/shared/cdn_verify.sh
source "$ROOT_DIR/Scripts/lib/shared/cdn_verify.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    # Note: shared module uses _SHARED_CDN_VERIFY_SOURCED as guard variable
    if [[ -n "${_SHARED_CDN_VERIFY_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(verify_cdn_availability wait_for_cdn_propagation verify_all_cdn_availability)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Run tests
echo "Running cdn_verify.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist

echo "========================================"
echo "All tests passed!"
