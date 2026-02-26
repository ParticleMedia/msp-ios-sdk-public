#!/usr/bin/env bash
# Unit tests for pod_publish.sh module
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
is_binary_distribution() { return 1; }
check_pod_published_on_trunk() { return 1; }
check_pod_availability() { return 1; }
msp_state_get_pod_status() { echo "unknown"; }
msp_state_mark_pod_status() { :; }
create_or_verify_github_release() { return 0; }
upload_zip_to_github() { return 0; }
probe_zip_url() { return 0; }
export -f is_binary_distribution check_pod_published_on_trunk check_pod_availability
export -f msp_state_get_pod_status msp_state_mark_pod_status
export -f create_or_verify_github_release upload_zip_to_github probe_zip_url

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/pods/lib/pod_publish.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_POD_PUBLISH_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: functions exist
test_functions_exist() {
    local funcs=(publish_pod_with_resume publish_pod_to_cocoapods acquire_github_release_lock release_github_release_lock)
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: publish_pod_to_cocoapods returns early in dry-run mode
test_publish_dry_run() {
    export DRY_RUN="true"
    export ROOT_DIR
    export VERSION="1.0.0"

    # Create mock podspec
    mkdir -p "$ROOT_DIR/Build/ReleasePodspecs"
    echo "Pod::Spec.new { |s| s.version = '1.0.0' }" > "$ROOT_DIR/Build/ReleasePodspecs/TestPod.podspec"

    if publish_pod_to_cocoapods "TestPod" "1.0.0" 2>/dev/null; then
        test_pass "publish_pod_to_cocoapods returns 0 in dry-run mode"
    else
        test_fail "publish_pod_to_cocoapods should return 0 in dry-run mode"
    fi

    rm -f "$ROOT_DIR/Build/ReleasePodspecs/TestPod.podspec"
    unset DRY_RUN VERSION
}

# Run tests
echo "Running pod_publish.sh unit tests..."
echo "========================================"

test_module_guard
test_functions_exist
test_publish_dry_run

echo "========================================"
echo "All tests passed!"
