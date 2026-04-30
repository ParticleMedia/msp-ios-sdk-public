#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/unfreeze.sh
# ============================================================================
# Verifies guard conditions, cherry-pick detection, branch deletion,
# KEEP_BRANCH support, and state file cleanup via static analysis.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$HELPERS_DIR/helpers.sh"

PASSED=0
FAILED=0
UNFREEZE_SCRIPT="$ROOT_DIR/Scripts/unfreeze.sh"

pass() { echo -e "${_GREEN:-}✓${_NC:-} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${_RED:-}✗${_NC:-} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------

test_unfreeze_script_is_executable() {
    if [[ -x "$UNFREEZE_SCRIPT" ]]; then
        pass "unfreeze.sh is executable"
    else
        fail "unfreeze.sh should be executable"
    fi
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_unfreeze_requires_nb_version() {
    if grep -q 'NB_VERSION is required' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: exits with error when NB_VERSION is missing"
    else
        fail "unfreeze: should exit with error when NB_VERSION is missing"
    fi
}

test_unfreeze_reads_nb_version_from_state_file() {
    if grep -q 'STATE_FILE' "$UNFREEZE_SCRIPT" &&
       grep -q 'nb_version' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: falls back to reading NB_VERSION from .msp-freeze-state.json"
    else
        fail "unfreeze: should fall back to reading NB_VERSION from state file"
    fi
}

test_unfreeze_constructs_branch_name() {
    if grep -q 'freeze/nb-' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: branch name uses freeze/nb-{NB_VERSION} pattern"
    else
        fail "unfreeze: branch name should follow freeze/nb-{NB_VERSION} pattern"
    fi
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

test_unfreeze_checks_clean_working_tree() {
    if grep -q 'git diff --quiet' "$UNFREEZE_SCRIPT" &&
       grep -q 'git diff --cached --quiet' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: checks both staged and unstaged changes"
    else
        fail "unfreeze: should check working tree cleanliness"
    fi
}

test_unfreeze_verifies_remote_branch_exists() {
    if grep -q 'ls-remote' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: verifies freeze branch exists on remote before proceeding"
    else
        fail "unfreeze: should verify freeze branch exists on remote"
    fi
}

# ---------------------------------------------------------------------------
# Cherry-pick detection
# ---------------------------------------------------------------------------

test_unfreeze_uses_git_cherry() {
    if grep -q 'git cherry' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: uses git cherry to detect un-cherry-picked commits"
    else
        fail "unfreeze: should use git cherry to detect un-cherry-picked commits"
    fi
}

test_unfreeze_aborts_on_missing_cherry_picks() {
    if grep -q 'Cherry-pick these commits\|cherry-pick' "$UNFREEZE_SCRIPT" &&
       grep -q 'die\|exit 1' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: aborts with guidance when cherry-picks are missing"
    else
        fail "unfreeze: should abort and list missing commits when cherry-picks are missing"
    fi
}

test_unfreeze_fetches_before_cherry_check() {
    if grep -q 'git fetch origin' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: fetches from remote before cherry-pick check"
    else
        fail "unfreeze: should git fetch origin before running git cherry"
    fi
}

# ---------------------------------------------------------------------------
# Branch deletion
# ---------------------------------------------------------------------------

test_unfreeze_deletes_remote_branch() {
    if grep -q 'git push origin --delete' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: deletes remote freeze branch"
    else
        fail "unfreeze: should delete remote freeze branch with git push origin --delete"
    fi
}

test_unfreeze_deletes_local_branch() {
    if grep -q 'git branch -d' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: deletes local freeze branch if it exists"
    else
        fail "unfreeze: should delete local freeze branch with git branch -d"
    fi
}

test_unfreeze_supports_keep_branch() {
    if grep -q 'KEEP_BRANCH' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: supports KEEP_BRANCH=1 to skip branch deletion"
    else
        fail "unfreeze: should support KEEP_BRANCH=1 to keep branch for reference"
    fi
}

# ---------------------------------------------------------------------------
# State file cleanup
# ---------------------------------------------------------------------------

test_unfreeze_removes_state_file() {
    if grep -q 'rm.*STATE_FILE\|rm.*msp-freeze-state' "$UNFREEZE_SCRIPT"; then
        pass "unfreeze: removes .msp-freeze-state.json on success"
    else
        fail "unfreeze: should remove .msp-freeze-state.json on successful unfreeze"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running unfreeze.sh tests..."
echo "============================================"

test_unfreeze_script_is_executable
test_unfreeze_requires_nb_version
test_unfreeze_reads_nb_version_from_state_file
test_unfreeze_constructs_branch_name
test_unfreeze_checks_clean_working_tree
test_unfreeze_verifies_remote_branch_exists
test_unfreeze_uses_git_cherry
test_unfreeze_aborts_on_missing_cherry_picks
test_unfreeze_fetches_before_cherry_check
test_unfreeze_deletes_remote_branch
test_unfreeze_deletes_local_branch
test_unfreeze_supports_keep_branch
test_unfreeze_removes_state_file

echo "============================================"
echo "Unfreeze tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
