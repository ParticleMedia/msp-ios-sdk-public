#!/usr/bin/env bash
# Unit tests for release/orchestrator/lib/notify_builder.sh module
# TDD: Tests written first, then module implemented

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source logger only
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/orchestrator/lib/notify_builder.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_ORCH_NOTIFY_BUILDER_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: common functions exist
test_functions_exist() {
    local funcs=(
        orch_build_module_list
        orch_build_remote_status
        orch_build_local_status
        orch_build_device_status
        orch_build_xcf_status
        orch_build_verify_status
        orch_build_notify_json
    )
    for fn in "${funcs[@]}"; do
        if command -v "$fn" &>/dev/null; then
            test_pass "$fn function exists"
        else
            test_fail "$fn function should exist"
        fi
    done
}

# Test: build module list formats correctly
test_build_module_list_empty() {
    local result
    result=$(orch_build_module_list)
    if [[ "$result" == "    - (none)" ]]; then
        test_pass "orch_build_module_list returns '(none)' when empty"
    else
        test_fail "orch_build_module_list should return '(none)' when empty, got: $result"
    fi
}

# Test: build module list with items
test_build_module_list_with_items() {
    local result
    result=$(orch_build_module_list "MSPCore" "MSPAdapter")
    if [[ "$result" == *"MSPCore"* ]] && [[ "$result" == *"MSPAdapter"* ]]; then
        test_pass "orch_build_module_list includes provided modules"
    else
        test_fail "orch_build_module_list should include MSPCore and MSPAdapter, got: $result"
    fi
}

# Test: build remote status returns empty for no execution
test_build_remote_status_empty() {
    # Unset execution flags
    unset REMOTE_SPM_EXECUTED
    unset REMOTE_PODS_EXECUTED
    local result
    result=$(orch_build_remote_status)
    if [[ -z "$result" ]]; then
        test_pass "orch_build_remote_status returns empty when no execution"
    else
        test_fail "orch_build_remote_status should return empty when no execution, got: $result"
    fi
}

# Test: build notify JSON produces valid JSON structure
test_build_notify_json_structure() {
    local result
    result=$(orch_build_notify_json "1.0.0" "test@test.com" "5m 0s" "{}" "{}" "{}" "{}" "{}")

    # Check it contains required fields
    if [[ "$result" == *'"version"'* ]] && \
       [[ "$result" == *'"author"'* ]] && \
       [[ "$result" == *'"duration"'* ]] && \
       [[ "$result" == *'"timestamp"'* ]]; then
        test_pass "orch_build_notify_json contains required fields"
    else
        test_fail "orch_build_notify_json should contain version, author, duration, timestamp"
    fi
}

# Test: build local verification status from state file
test_build_local_status_from_state() {
    # Create temp state file
    local temp_state
    temp_state=$(mktemp)
    cat > "$temp_state" << 'EOF'
{
  "steps": {
    "run_local_verification": {
      "status": "success"
    }
  }
}
EOF

    local result
    result=$(orch_build_local_status "$temp_state" "podspec")
    rm -f "$temp_state"

    if [[ "$result" == *"Local"* ]] && [[ "$result" == *"PASS"* ]]; then
        test_pass "orch_build_local_status reads success from state file"
    else
        test_fail "orch_build_local_status should read success status, got: $result"
    fi
}

# Run tests
echo "Running release/orchestrator/lib/notify_builder.sh unit tests..."
echo "=============================================================="

test_module_guard
test_functions_exist
test_build_module_list_empty
test_build_module_list_with_items
test_build_remote_status_empty
test_build_notify_json_structure
test_build_local_status_from_state

echo "=============================================================="
echo "All tests passed!"
