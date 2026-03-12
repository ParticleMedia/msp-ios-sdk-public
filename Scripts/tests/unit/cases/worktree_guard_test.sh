#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/lib/worktree_guard.sh
# @test msp_enforce_main_repo_or_exit() always passes (guard disabled)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/../helpers.sh"

GUARD_SH="$REPO_ROOT/Scripts/lib/worktree_guard.sh"

# ============================================================================
# Code existence tests
# ============================================================================

test_guard_file_exists() {
    assert_file_exists "$GUARD_SH" "worktree_guard.sh should exist"
}

test_function_defined() {
    # shellcheck source=Scripts/lib/worktree_guard.sh
    source "$GUARD_SH"
    local rc=0
    command -v msp_enforce_main_repo_or_exit &>/dev/null || rc=$?
    assert_equals "0" "$rc" "msp_enforce_main_repo_or_exit function should be defined after sourcing"
}

# ============================================================================
# Behavior tests
# ============================================================================

test_normal_repo_passes() {
    # In the main repo, calling the guard should succeed (exit 0)
    # shellcheck source=Scripts/lib/worktree_guard.sh
    source "$GUARD_SH"
    local rc=0
    msp_enforce_main_repo_or_exit || rc=$?
    assert_equals "0" "$rc" "msp_enforce_main_repo_or_exit should pass in main repo"
}

test_guard_is_noop() {
    # The guard is currently disabled — it should always return 0
    # This matches Patch K design: worktrees share git state and ROOT_DIR resolves correctly
    # shellcheck source=Scripts/lib/worktree_guard.sh
    source "$GUARD_SH"
    local body
    body=$(declare -f msp_enforce_main_repo_or_exit)
    if echo "$body" | grep -q 'return 0'; then
        : # expected
    else
        fail_test "msp_enforce_main_repo_or_exit should contain 'return 0' (guard disabled)"
    fi
}

# ============================================================================
# Run tests
# ============================================================================

info "Running worktree_guard.sh unit tests..."

test_guard_file_exists
test_function_defined
test_normal_repo_passes
test_guard_is_noop

echo ""
info "All worktree_guard.sh tests passed!"
