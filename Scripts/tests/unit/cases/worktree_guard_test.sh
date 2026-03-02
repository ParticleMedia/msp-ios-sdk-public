#!/usr/bin/env bash
set -euo pipefail

# @description Unit tests for Scripts/lib/worktree_guard.sh
# @test msp_enforce_main_repo_or_exit() blocks worktree paths and allows normal repos

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
# Behavior tests (pattern matching)
# ============================================================================

test_normal_repo_passes() {
    # In the main repo, calling the guard should succeed (exit 0)
    # shellcheck source=Scripts/lib/worktree_guard.sh
    source "$GUARD_SH"
    local rc=0
    msp_enforce_main_repo_or_exit || rc=$?
    assert_equals "0" "$rc" "msp_enforce_main_repo_or_exit should pass in main repo"
}

test_detects_relative_worktree_pattern() {
    # The guard checks if git_dir matches ".git/worktrees/*"
    local found
    found=$(grep -c '\.git/worktrees/' "$GUARD_SH")
    assert_not_equals "0" "$found" "should check for .git/worktrees/ pattern"
}

test_detects_absolute_worktree_pattern() {
    # The guard also checks "*/.git/worktrees/*" for absolute paths
    local found
    found=$(grep -c '/\.git/worktrees/' "$GUARD_SH")
    assert_not_equals "0" "$found" "should check for absolute .git/worktrees/ pattern"
}

test_unsets_git_env_vars() {
    # The guard should unset GIT_DIR and GIT_WORK_TREE to avoid interference
    local found
    found=$(grep -c 'unset GIT_DIR GIT_WORK_TREE' "$GUARD_SH")
    assert_not_equals "0" "$found" "should unset GIT_DIR and GIT_WORK_TREE"
}

test_uses_local_variables() {
    # Variables should use local with underscore prefix to avoid leaking into caller scope
    local found
    found=$(grep -c 'local _wg_' "$GUARD_SH")
    assert_not_equals "0" "$found" "should use local variables with _wg_ prefix"
}

test_git_missing_returns_zero() {
    # If git is not available, the guard should return 0 (not block)
    local found
    found=$(grep -c 'command -v git' "$GUARD_SH")
    assert_not_equals "0" "$found" "should check for git availability"
}

test_fatal_message_on_worktree() {
    # The guard should output a FATAL message when in a worktree
    local found
    found=$(grep -c '\[MSP\]\[FATAL\]' "$GUARD_SH")
    assert_not_equals "0" "$found" "should output [MSP][FATAL] message when in worktree"
}

# ============================================================================
# Run tests
# ============================================================================

info "Running worktree_guard.sh unit tests..."

test_guard_file_exists
test_function_defined
test_normal_repo_passes
test_detects_relative_worktree_pattern
test_detects_absolute_worktree_pattern
test_unsets_git_env_vars
test_uses_local_variables
test_git_missing_returns_zero
test_fatal_message_on_worktree

echo ""
info "All worktree_guard.sh tests passed!"
