#!/usr/bin/env bash
# Unit tests for release_orchestration.sh module
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

# Mock dependencies
publish_pod_to_cocoapods() { return 0; }
smart_wait_for_pod_availability() { return 0; }
update_podspec_for_release() { return 0; }
create_github_release_for_pod() { return 0; }
check_pod_availability() { return 0; }
ensure_novacore_xcframework() { return 0; }
log_section() { :; }
log_title() { :; }
msp_state_mark_step_completed() { :; }
msp_state_mark_step_failed() { :; }
metrics::start() { :; }
metrics::end() { :; }
export -f publish_pod_to_cocoapods smart_wait_for_pod_availability update_podspec_for_release
export -f create_github_release_for_pod check_pod_availability ensure_novacore_xcframework
export -f log_section log_title msp_state_mark_step_completed msp_state_mark_step_failed

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/pods/lib/release_orchestration.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_RELEASE_ORCHESTRATION_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(release_msp_ioscore release_msp_shared_libraries release_msp_googleadstypes release_single_adapter release_adapters release_msp_core)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Run tests
echo "Running release_orchestration.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist

echo "========================================"
echo "All tests passed!"
