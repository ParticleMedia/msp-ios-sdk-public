#!/usr/bin/env bash
# ============================================================================
# Unit Tests for Scripts/freeze.sh
# ============================================================================
# Verifies guard conditions, branch naming, git operations, state file
# writing, and notification output via static analysis.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$HELPERS_DIR/helpers.sh"

PASSED=0
FAILED=0
FREEZE_SCRIPT="$ROOT_DIR/Scripts/freeze.sh"

pass() { echo -e "${_GREEN:-}✓${_NC:-} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${_RED:-}✗${_NC:-} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------

test_freeze_script_is_executable() {
    if [[ -x "$FREEZE_SCRIPT" ]]; then
        pass "freeze.sh is executable"
    else
        fail "freeze.sh should be executable"
    fi
}

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_freeze_requires_nb_version() {
    if grep -q 'NB_VERSION is required' "$FREEZE_SCRIPT"; then
        pass "freeze: exits with error when NB_VERSION is missing"
    else
        fail "freeze: should exit with error when NB_VERSION is missing"
    fi
}

test_freeze_constructs_branch_name() {
    if grep -q 'freeze/nb-' "$FREEZE_SCRIPT"; then
        pass "freeze: branch name uses freeze/nb-{NB_VERSION} pattern"
    else
        fail "freeze: branch name should follow freeze/nb-{NB_VERSION} pattern"
    fi
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

test_freeze_checks_clean_working_tree() {
    if grep -q 'git diff --quiet' "$FREEZE_SCRIPT" &&
       grep -q 'git diff --cached --quiet' "$FREEZE_SCRIPT"; then
        pass "freeze: checks both staged and unstaged changes"
    else
        fail "freeze: should check working tree cleanliness (staged + unstaged)"
    fi
}

test_freeze_checks_develop_branch() {
    if grep -q '"develop"' "$FREEZE_SCRIPT" &&
       grep -q 'abbrev-ref HEAD' "$FREEZE_SCRIPT"; then
        pass "freeze: validates current branch is develop"
    else
        fail "freeze: should validate current branch is develop"
    fi
}

test_freeze_checks_branch_not_exists() {
    if grep -q 'show-ref --verify' "$FREEZE_SCRIPT" ||
       grep -q 'ls-remote' "$FREEZE_SCRIPT"; then
        pass "freeze: checks freeze branch does not already exist"
    else
        fail "freeze: should check freeze branch does not already exist"
    fi
}

test_freeze_checks_no_active_state() {
    if grep -q 'STATE_FILE' "$FREEZE_SCRIPT" &&
       grep -q 'active freeze state\|An active freeze' "$FREEZE_SCRIPT"; then
        pass "freeze: aborts if a freeze state file already exists"
    else
        fail "freeze: should abort if .msp-freeze-state.json already exists"
    fi
}

# ---------------------------------------------------------------------------
# Git operations
# ---------------------------------------------------------------------------

test_freeze_pulls_develop() {
    if grep -q 'git pull origin develop' "$FREEZE_SCRIPT"; then
        pass "freeze: pulls latest develop before branching"
    else
        fail "freeze: should pull origin develop before creating branch"
    fi
}

test_freeze_creates_branch() {
    if grep -q 'git checkout -b' "$FREEZE_SCRIPT"; then
        pass "freeze: creates freeze branch with git checkout -b"
    else
        fail "freeze: should create freeze branch with git checkout -b"
    fi
}

test_freeze_pushes_branch() {
    if grep -q 'git push -u origin' "$FREEZE_SCRIPT"; then
        pass "freeze: pushes branch to remote with -u flag"
    else
        fail "freeze: should push freeze branch to remote with git push -u origin"
    fi
}

test_freeze_returns_to_develop() {
    if grep -q 'git checkout develop' "$FREEZE_SCRIPT"; then
        pass "freeze: switches back to develop after creating freeze branch"
    else
        fail "freeze: should switch back to develop after creating freeze branch"
    fi
}

# ---------------------------------------------------------------------------
# State file
# ---------------------------------------------------------------------------

test_freeze_writes_state_file() {
    if grep -q '\.msp-freeze-state\.json' "$FREEZE_SCRIPT" &&
       grep -q 'nb_version' "$FREEZE_SCRIPT" &&
       grep -q 'freeze_branch' "$FREEZE_SCRIPT" &&
       grep -q 'frozen_at' "$FREEZE_SCRIPT"; then
        pass "freeze: writes .msp-freeze-state.json with nb_version, freeze_branch, frozen_at"
    else
        fail "freeze: should write .msp-freeze-state.json with required fields"
    fi
}

# ---------------------------------------------------------------------------
# Notification template
# ---------------------------------------------------------------------------

test_freeze_prints_notification_template() {
    if grep -q 'SDK Code Freeze' "$FREEZE_SCRIPT" &&
       grep -q 'Release branch' "$FREEZE_SCRIPT" &&
       grep -q 'Planned release' "$FREEZE_SCRIPT"; then
        pass "freeze: prints team notification template with release info"
    else
        fail "freeze: should print team notification template"
    fi
}

# ============================================================================
# Run Tests
# ============================================================================

echo "Running freeze.sh tests..."
echo "============================================"

test_freeze_script_is_executable
test_freeze_requires_nb_version
test_freeze_constructs_branch_name
test_freeze_checks_clean_working_tree
test_freeze_checks_develop_branch
test_freeze_checks_branch_not_exists
test_freeze_checks_no_active_state
test_freeze_pulls_develop
test_freeze_creates_branch
test_freeze_pushes_branch
test_freeze_returns_to_develop
test_freeze_writes_state_file
test_freeze_prints_notification_template

echo "============================================"
echo "Freeze tests: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
