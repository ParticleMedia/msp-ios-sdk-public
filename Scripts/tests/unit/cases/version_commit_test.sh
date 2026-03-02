#!/usr/bin/env bash
# Unit tests for version_commit.sh module

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Minimal test helpers
test_pass() { echo "PASS: $1"; }
test_fail() { echo "FAIL: $1"; exit 1; }

# Source required modules
source "$ROOT_DIR/Scripts/lib/common.sh" 2>/dev/null || true
source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true

# Source version_management.sh first (dependency)
source "$ROOT_DIR/Scripts/release/publish/pods/lib/version_management.sh" 2>/dev/null || true

# Source module under test
source "$ROOT_DIR/Scripts/release/publish/pods/lib/version_commit.sh"

MODULE_FILE="$ROOT_DIR/Scripts/release/publish/pods/lib/version_commit.sh"

# Test: module guard prevents double sourcing
test_module_guard() {
    if [[ -n "${_VERSION_COMMIT_SOURCED:-}" ]]; then
        test_pass "Module guard variable is set"
    else
        test_fail "Module guard variable should be set after sourcing"
    fi
}

# Test: update_and_commit_plist_version function exists (DRY helper)
test_update_and_commit_exists() {
    if command -v update_and_commit_plist_version &>/dev/null; then
        test_pass "update_and_commit_plist_version function exists"
    else
        test_fail "update_and_commit_plist_version function should exist"
    fi
}

# Test: ensure_version_files_committed function exists (safety net)
test_ensure_version_files_committed_exists() {
    if command -v ensure_version_files_committed &>/dev/null; then
        test_pass "ensure_version_files_committed function exists"
    else
        test_fail "ensure_version_files_committed function should exist"
    fi
}

# Test: backward compatibility alias exists
test_backward_compat_alias() {
    if command -v ensure_mspcore_version_committed &>/dev/null; then
        test_pass "ensure_mspcore_version_committed backward compat alias exists"
    else
        test_fail "ensure_mspcore_version_committed alias should exist"
    fi
}

# Test: update_and_commit_plist_version handles both mspcore and novacore
test_update_and_commit_handles_both_targets() {
    if grep -q '"mspcore"' "$MODULE_FILE" && grep -q '"novacore"' "$MODULE_FILE"; then
        test_pass "update_and_commit_plist_version handles mspcore and novacore targets"
    else
        test_fail "update_and_commit_plist_version should handle both mspcore and novacore"
    fi
}

# Test: update_and_commit_plist_version calls both update functions
test_update_and_commit_calls_both_update_functions() {
    if grep -q 'update_config_plist_version' "$MODULE_FILE" && \
       grep -q 'update_novacore_config_plist_version' "$MODULE_FILE"; then
        test_pass "Calls both update_config_plist_version and update_novacore_config_plist_version"
    else
        test_fail "Should call both MSPCore and NovaCore update functions"
    fi
}

# Test: update_and_commit_plist_version has git add + git commit
test_update_and_commit_has_git_ops() {
    if grep -q 'git add' "$MODULE_FILE" && grep -q 'git commit' "$MODULE_FILE"; then
        test_pass "update_and_commit_plist_version has git add + git commit"
    else
        test_fail "update_and_commit_plist_version should have git add + git commit"
    fi
}

# Test: safety net references sdk_version.conf
test_safety_net_references_ssot() {
    if grep -q 'sdk_version\.conf' "$MODULE_FILE"; then
        test_pass "Safety net references sdk_version.conf"
    else
        test_fail "Safety net should reference sdk_version.conf"
    fi
}

# Test: safety net checks both MSPCore and NovaCore Config.plist
test_safety_net_checks_both_plists() {
    local block
    block=$(awk '/^ensure_version_files_committed/,/^}/' "$MODULE_FILE")

    local has_mspcore has_novacore
    has_mspcore=$(echo "$block" | grep -c 'MSPCore' || true)
    has_novacore=$(echo "$block" | grep -c 'NovaCore' || true)

    if [[ "$has_mspcore" -gt 0 ]] && [[ "$has_novacore" -gt 0 ]]; then
        test_pass "Safety net checks both MSPCore and NovaCore"
    else
        test_fail "Safety net should check both MSPCore ($has_mspcore refs) and NovaCore ($has_novacore refs)"
    fi
}

# Test: dry run mode skips commit operations
test_dry_run_skips() {
    export DRY_RUN="true"
    export ROOT_DIR

    if ensure_version_files_committed "1.0.0" 2>/dev/null; then
        test_pass "ensure_version_files_committed returns 0 in dry-run mode"
    else
        test_fail "ensure_version_files_committed should return 0 in dry-run mode"
    fi

    unset DRY_RUN
}

# Test: adapter functions have been removed
test_adapter_functions_removed() {
    if ! grep -vE '^\s*#' "$MODULE_FILE" | grep -q 'ensure_adapter_version_committed'; then
        test_pass "ensure_adapter_version_committed removed from module"
    else
        test_fail "ensure_adapter_version_committed should be removed"
    fi

    if ! grep -vE '^\s*#' "$MODULE_FILE" | grep -q 'commit_adapter_version_updates'; then
        test_pass "commit_adapter_version_updates removed from module"
    else
        test_fail "commit_adapter_version_updates should be removed"
    fi
}

# Run tests
echo "Running version_commit.sh unit tests..."
echo "========================================"

test_module_guard
test_update_and_commit_exists
test_ensure_version_files_committed_exists
test_backward_compat_alias
test_update_and_commit_handles_both_targets
test_update_and_commit_calls_both_update_functions
test_update_and_commit_has_git_ops
test_safety_net_references_ssot
test_safety_net_checks_both_plists
test_dry_run_skips
test_adapter_functions_removed

echo "========================================"
echo "All tests passed!"
