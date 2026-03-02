#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/release/orchestrator/branch.sh
# ============================================================================
# Verifies that git pull, git push, and git push --delete operations
# have retry logic with correct attempt counts and sleep intervals.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test helpers
source "$HELPERS_DIR/helpers.sh"

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

BRANCH_SCRIPT="$ROOT_DIR/Scripts/release/orchestrator/branch.sh"

# ============================================================================
# Test Cases
# ============================================================================

test_git_pull_has_retry_loop() {
    if grep -q 'max_pull_attempts=3' "$BRANCH_SCRIPT" &&
       grep -q 'pull_attempt' "$BRANCH_SCRIPT" &&
       grep -q 'pull_success' "$BRANCH_SCRIPT"; then
        pass "create_release_branch: git pull has retry loop with 3 attempts"
    else
        fail "create_release_branch: git pull should have retry loop with max_pull_attempts=3"
    fi
}

test_git_pull_has_sleep_interval() {
    # Verify sleep 3 appears in the pull retry context
    if grep -A2 'pull_attempt.*lt.*max_pull_attempts' "$BRANCH_SCRIPT" | grep -q 'sleep 3'; then
        pass "create_release_branch: git pull retry has 3s sleep interval"
    else
        fail "create_release_branch: git pull retry should have sleep 3"
    fi
}

test_git_pull_exits_on_failure() {
    if grep -A2 'pull_success.*false' "$BRANCH_SCRIPT" | grep -q 'exit 1'; then
        pass "create_release_branch: exits 1 when git pull exhausts retries"
    else
        fail "create_release_branch: should exit 1 when git pull fails after retries"
    fi
}

test_git_push_has_retry_loop() {
    if grep -q 'max_push_attempts=3' "$BRANCH_SCRIPT" &&
       grep -q 'push_attempt' "$BRANCH_SCRIPT" &&
       grep -q 'push_success' "$BRANCH_SCRIPT"; then
        pass "push_release_branch: git push has retry loop with 3 attempts"
    else
        fail "push_release_branch: git push should have retry loop with max_push_attempts=3"
    fi
}

test_git_push_has_sleep_interval() {
    if grep -A2 'push_attempt.*lt.*max_push_attempts' "$BRANCH_SCRIPT" | grep -q 'sleep 3'; then
        pass "push_release_branch: git push retry has 3s sleep interval"
    else
        fail "push_release_branch: git push retry should have sleep 3"
    fi
}

test_git_push_exits_on_failure() {
    if grep -A2 'push_success.*false' "$BRANCH_SCRIPT" | grep -q 'exit 1'; then
        pass "push_release_branch: exits 1 when git push exhausts retries"
    else
        fail "push_release_branch: should exit 1 when git push fails after retries"
    fi
}

test_git_delete_has_retry_loop() {
    if grep -q 'max_delete_attempts=2' "$BRANCH_SCRIPT" &&
       grep -q 'delete_attempt' "$BRANCH_SCRIPT" &&
       grep -q 'delete_success' "$BRANCH_SCRIPT"; then
        pass "check_release_branch: git push --delete has retry loop with 2 attempts"
    else
        fail "check_release_branch: git push --delete should have retry loop with max_delete_attempts=2"
    fi
}

test_git_delete_warns_on_failure() {
    # Delete failure should warn, not exit
    if grep -A2 'delete_success.*true' "$BRANCH_SCRIPT" | grep -q 'log::success'; then
        # Also check that failure path uses warn, not exit
        if grep -q 'Could not delete remote branch.*continuing' "$BRANCH_SCRIPT"; then
            pass "check_release_branch: warns (not exits) when delete fails"
        else
            fail "check_release_branch: should warn with 'continuing' message on delete failure"
        fi
    else
        fail "check_release_branch: should log success on delete success"
    fi
}

test_git_delete_does_not_exit_on_failure() {
    # Extract the delete retry block and verify no exit 1 after delete_success==false
    local delete_block
    delete_block=$(awk '/max_delete_attempts=2/,/Could not delete remote branch/' "$BRANCH_SCRIPT")

    if echo "$delete_block" | grep -q 'exit 1'; then
        fail "check_release_branch: delete retry should NOT exit 1 on failure"
    else
        pass "check_release_branch: delete retry does not exit 1 on failure"
    fi
}

test_branch_script_is_executable() {
    if [[ -x "$BRANCH_SCRIPT" ]]; then
        pass "branch.sh is executable"
    else
        fail "branch.sh should be executable"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running branch.sh retry logic tests..."
echo "============================================"

test_git_pull_has_retry_loop
test_git_pull_has_sleep_interval
test_git_pull_exits_on_failure
test_git_push_has_retry_loop
test_git_push_has_sleep_interval
test_git_push_exits_on_failure
test_git_delete_has_retry_loop
test_git_delete_warns_on_failure
test_git_delete_does_not_exit_on_failure
test_branch_script_is_executable

echo "============================================"
echo "Branch retry tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
