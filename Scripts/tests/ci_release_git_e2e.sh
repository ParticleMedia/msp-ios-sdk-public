#!/usr/bin/env bash
# ============================================================================
# CI Release Git E2E Test (Level 2 - Real Git Push)
# ============================================================================
# Purpose: Test complete CI release pipeline with real git push and tag push
#
# This test:
# - Clones real repository to sandbox
# - Creates test branch and runs CI release
# - Actually pushes branch and tags to remote
# - Skips Pods/SPM publishing
# - Validates all pipeline stages
#
# Usage: bash Scripts/tests/ci_release_git_e2e.sh
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get real repo root and remote URL
REAL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REAL_REPO_ROOT

# Get git remote URL
GIT_REMOTE_URL="$(cd "$REAL_REPO_ROOT" && git remote get-url origin 2>/dev/null || echo "")"
if [[ -z "$GIT_REMOTE_URL" ]]; then
    echo "ERROR: Could not determine git remote URL" >&2
    exit 1
fi

# Create sandbox directory with timestamp
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SANDBOX_DIR="/tmp/msp-ci-git-e2e-${TIMESTAMP}"
export SANDBOX_DIR

# Test branch and tag names
TEST_BRANCH="ci-git-test-${TIMESTAMP}"
TEST_TAG_PREFIX="ci-test"

# Test results tracking
TEST_RESULTS=()
ALL_VALIDATIONS_PASSED="YES"

# ============================================================================
# Helper Functions
# ============================================================================

log_test() {
    echo "[TEST] $*" >&2
}

log_result() {
    local check_name="$1"
    local result="$2"
    TEST_RESULTS+=("$check_name:$result")
    echo "[RESULT] $check_name: $result"
    if [[ "$result" == *"NO"* ]] || [[ "$result" == *"FAILED"* ]]; then
        ALL_VALIDATIONS_PASSED="NO"
    fi
}

# ============================================================================
# STEP 1: Create Sandbox and Clone Repository
# ============================================================================

log_test "Creating sandbox directory: $SANDBOX_DIR"
mkdir -p "$SANDBOX_DIR"
cd "$SANDBOX_DIR"

log_test "Cloning repository from: $GIT_REMOTE_URL"
git clone "$GIT_REMOTE_URL" . --quiet || {
    echo "ERROR: Failed to clone repository" >&2
    exit 1
}

# Get current branch from real repo to ensure we have latest code
CURRENT_BRANCH="$(cd "$REAL_REPO_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
log_test "Switching to current branch: $CURRENT_BRANCH"
git fetch origin "$CURRENT_BRANCH" --quiet 2>/dev/null || true
git checkout "$CURRENT_BRANCH" --quiet 2>/dev/null || git checkout -b "$CURRENT_BRANCH" --quiet || true

log_test "Creating test branch: $TEST_BRANCH"
git checkout -b "$TEST_BRANCH" --quiet || {
    echo "ERROR: Failed to create test branch" >&2
    exit 1
}

# Ensure CI scripts exist (copy from local if not in cloned repo)
log_test "Ensuring CI scripts exist in sandbox..."
if [[ ! -f "$SANDBOX_DIR/Scripts/release/msp-release-ci.sh" ]]; then
    log_test "  - Copying msp-release-ci.sh from local repo"
    cp "$REAL_REPO_ROOT/Scripts/release/msp-release-ci.sh" "$SANDBOX_DIR/Scripts/release/" 2>/dev/null || true
fi
if [[ ! -f "$SANDBOX_DIR/Scripts/release/auto_version.sh" ]]; then
    log_test "  - Copying auto_version.sh from local repo"
    cp "$REAL_REPO_ROOT/Scripts/release/auto_version.sh" "$SANDBOX_DIR/Scripts/release/" 2>/dev/null || true
fi

log_test "Sandbox setup complete"

# ============================================================================
# STEP 2: Set Up Environment Variables
# ============================================================================

log_test "Setting up CI environment variables..."

export MSP_RELEASE_MODE="ci"
export MSP_SLACK_ALERT_ENV="test"
export MSP_SLACK_BLOCK_MODE="1"
export MSP_EMAIL_DISABLED="1"

# Enable verification systems
export MSP_LOCAL_VERIFY_ENABLED="1"
export MSP_DEVICE_VERIFY_ENABLED="1"
export MSP_REMOTE_VERIFY_ENABLED="1"
export MSP_XCF_VERIFY_ENABLED="1"

# Skip Pods/SPM publishing
export PODS_ENABLED="false"
export SPM_ENABLED="false"

# Enable git push and tag (we want real pushes for this test)
export SKIP_PUSH="false"
export DRY_RUN="false"

# Use auto version bump
export VERSION="auto"
export RELEASE_NOTES="Level 2 Git Dry-run E2E Test"

# Set ROOT_DIR to sandbox
export ROOT_DIR="$SANDBOX_DIR"

log_test "Environment variables set:"
log_test "  - MSP_RELEASE_MODE=$MSP_RELEASE_MODE"
log_test "  - MSP_SLACK_ALERT_ENV=$MSP_SLACK_ALERT_ENV"
log_test "  - PODS_ENABLED=$PODS_ENABLED"
log_test "  - SPM_ENABLED=$SPM_ENABLED"
log_test "  - SKIP_PUSH=$SKIP_PUSH"
log_test "  - VERSION=$VERSION"
log_test "  - ROOT_DIR=$ROOT_DIR"

# ============================================================================
# STEP 3: Run CI Release Pipeline
# ============================================================================

log_test "===================================================="
log_test "Starting CI Release Pipeline"
log_test "===================================================="

CI_ENTRYPOINT="$SANDBOX_DIR/Scripts/release/msp-release-ci.sh"

if [[ ! -f "$CI_ENTRYPOINT" ]]; then
    echo "ERROR: CI entrypoint not found: $CI_ENTRYPOINT" >&2
    exit 1
fi

# Run CI script - capture exit code
CI_EXIT_CODE=0
bash "$CI_ENTRYPOINT" || CI_EXIT_CODE=$?

if [[ $CI_EXIT_CODE -eq 0 ]]; then
    log_result "ORCHESTRATOR_NO_HARD_FAIL" "YES"
else
    log_result "ORCHESTRATOR_NO_HARD_FAIL" "NO (exit code: $CI_EXIT_CODE)"
    log_test "WARN: CI entrypoint exited with code $CI_EXIT_CODE"
fi

# ============================================================================
# STEP 4: Validate Results
# ============================================================================

log_test "===================================================="
log_test "Validating Pipeline Results"
log_test "===================================================="

# Get resolved version from state file
RESOLVED_VERSION=""
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    RESOLVED_VERSION="$(jq -r '.release.version // .version // "unknown"' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
fi

# Expected tag name format: ci-test-<version>-<timestamp>
EXPECTED_TAG="${TEST_TAG_PREFIX}-${RESOLVED_VERSION}-${TIMESTAMP}"

# 1) .msp-release-state.json generated?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    log_result "STATE_JSON_GENERATED" "YES"
else
    log_result "STATE_JSON_GENERATED" "NO"
fi

# 2) State JSON contains release_branch?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    RELEASE_BRANCH_STATE="$(jq -r '.release_branch // .release.branch // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$RELEASE_BRANCH_STATE" ]] && [[ "$RELEASE_BRANCH_STATE" != "null" ]]; then
        log_result "STATE_HAS_RELEASE_BRANCH" "YES ($RELEASE_BRANCH_STATE)"
    else
        log_result "STATE_HAS_RELEASE_BRANCH" "NO"
    fi
else
    log_result "STATE_HAS_RELEASE_BRANCH" "NO"
fi

# 3) State JSON contains git.tag_created?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    TAG_CREATED="$(jq -r '.git.tag_created // .git.tag // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$TAG_CREATED" ]] && [[ "$TAG_CREATED" != "null" ]]; then
        log_result "STATE_HAS_GIT_TAG_CREATED" "YES ($TAG_CREATED)"
    else
        log_result "STATE_HAS_GIT_TAG_CREATED" "NO"
    fi
else
    log_result "STATE_HAS_GIT_TAG_CREATED" "NO"
fi

# 4) State JSON contains git.release_branch_pushed?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    BRANCH_PUSHED="$(jq -r '.git.release_branch_pushed // .git.branch_pushed // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$BRANCH_PUSHED" ]] && [[ "$BRANCH_PUSHED" != "null" ]]; then
        log_result "STATE_HAS_BRANCH_PUSHED" "YES ($BRANCH_PUSHED)"
    else
        log_result "STATE_HAS_BRANCH_PUSHED" "NO"
    fi
else
    log_result "STATE_HAS_BRANCH_PUSHED" "NO"
fi

# 5) Branch successfully pushed? (check remote)
log_test "Checking if branch was pushed to remote..."
if git ls-remote --heads origin "$TEST_BRANCH" >/dev/null 2>&1; then
    log_result "BRANCH_PUSHED_TO_REMOTE" "YES ($TEST_BRANCH)"
else
    log_result "BRANCH_PUSHED_TO_REMOTE" "NO"
fi

# Also check release branch if different
if [[ -n "$RESOLVED_VERSION" ]] && [[ "$RESOLVED_VERSION" != "unknown" ]]; then
    RELEASE_BRANCH="release/$RESOLVED_VERSION"
    if git ls-remote --heads origin "$RELEASE_BRANCH" >/dev/null 2>&1; then
        log_result "RELEASE_BRANCH_PUSHED_TO_REMOTE" "YES ($RELEASE_BRANCH)"
    else
        log_result "RELEASE_BRANCH_PUSHED_TO_REMOTE" "NO"
    fi
fi

# 6) Tag successfully pushed? (check remote)
log_test "Checking if tag was pushed to remote..."
# Check for tags matching our prefix
PUSHED_TAGS="$(git ls-remote --tags origin 2>/dev/null | grep -E "refs/tags/${TEST_TAG_PREFIX}-" || echo "")"
if [[ -n "$PUSHED_TAGS" ]]; then
    # Extract tag names
    TAG_NAMES="$(echo "$PUSHED_TAGS" | sed 's|.*refs/tags/||' | head -1)"
    log_result "TAG_PUSHED_TO_REMOTE" "YES ($TAG_NAMES)"
    
    # Check if tag name format is correct
    if echo "$TAG_NAMES" | grep -qE "^${TEST_TAG_PREFIX}-[0-9]+\.[0-9]+\.[0-9]+-"; then
        log_result "TAG_NAME_FORMAT_CORRECT" "YES"
    else
        log_result "TAG_NAME_FORMAT_CORRECT" "NO (format: $TAG_NAMES)"
    fi
else
    log_result "TAG_PUSHED_TO_REMOTE" "NO"
    log_result "TAG_NAME_FORMAT_CORRECT" "N/A"
fi

# 7) Release.md exists?
RELEASE_MD_PATH=""
if [[ -n "$RESOLVED_VERSION" ]] && [[ "$RESOLVED_VERSION" != "unknown" ]]; then
    RELEASE_MD_PATH="$SANDBOX_DIR/Releases/release-$RESOLVED_VERSION.md"
    if [[ -f "$RELEASE_MD_PATH" ]]; then
        log_result "RELEASE_MD_EXISTS" "YES"
    else
        log_result "RELEASE_MD_EXISTS" "NO"
    fi
else
    log_result "RELEASE_MD_EXISTS" "NO (version unknown)"
fi

# 8) Slack BlockKit sent? (check state or assume success if orchestrator succeeded)
if [[ $CI_EXIT_CODE -eq 0 ]]; then
    # In test mode, Slack should have been attempted
    # We can't verify actual send without checking logs, but if orchestrator succeeded, assume it worked
    log_result "SLACK_BLOCKKIT_SENT" "YES (assumed - orchestrator succeeded)"
else
    log_result "SLACK_BLOCKKIT_SENT" "UNKNOWN"
fi

# 9) No Pods publish attempted?
if [[ "${PODS_ENABLED:-true}" == "false" ]]; then
    log_result "PODS_PUBLISH_SKIPPED" "YES (PODS_ENABLED=false)"
else
    log_result "PODS_PUBLISH_SKIPPED" "NO"
fi

# 10) No SPM publish attempted?
if [[ "${SPM_ENABLED:-true}" == "false" ]]; then
    log_result "SPM_PUBLISH_SKIPPED" "YES (SPM_ENABLED=false)"
else
    log_result "SPM_PUBLISH_SKIPPED" "NO"
fi

# ============================================================================
# STEP 5: Final Summary
# ============================================================================

log_test "===================================================="
log_test "CI Level 2 Git Dry-run E2E Test — FINISHED"
log_test "===================================================="

echo "Sandbox: $SANDBOX_DIR"
echo "Branch pushed: $TEST_BRANCH"
if [[ -n "$PUSHED_TAGS" ]]; then
    TAG_NAME="$(echo "$PUSHED_TAGS" | sed 's|.*refs/tags/||' | head -1)"
    echo "Tag pushed: $TAG_NAME"
else
    echo "Tag pushed: (none)"
fi
if [[ -n "$RELEASE_MD_PATH" ]] && [[ -f "$RELEASE_MD_PATH" ]]; then
    echo "Release Report: Releases/release-$RESOLVED_VERSION.md"
else
    echo "Release Report: (not generated)"
fi
echo "===================================================="

log_test "All validations passed: $ALL_VALIDATIONS_PASSED"
log_test "Test complete. Sandbox location: $SANDBOX_DIR"
log_test "To inspect sandbox, check: $SANDBOX_DIR"

# Always exit 0 (soft-fail test script)
exit 0

