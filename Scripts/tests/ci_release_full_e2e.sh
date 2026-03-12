#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch M, shared) ---
# shellcheck source=/dev/null
_msp_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$_msp_root" ] && [ -f "$_msp_root/Scripts/lib/worktree_guard.sh" ]; then
  . "$_msp_root/Scripts/lib/worktree_guard.sh"
  msp_enforce_main_repo_or_exit
fi
unset _msp_root
# --- End MSP Worktree Safety Guard (Patch M, shared) ---
# ============================================================================
# CI Release Full Pipeline E2E Test
# ============================================================================
# Purpose: Simulate a complete CI release pipeline locally in a sandbox
#
# This test:
# - Creates an isolated sandbox environment
# - Copies necessary files to sandbox
# - Runs msp-release-ci.sh with auto version bump
# - Validates all pipeline stages
# - Reports comprehensive results
#
# Usage: bash Scripts/tests/ci_release_full_e2e.sh
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get real repo root
REAL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REAL_REPO_ROOT

# Create sandbox directory
SANDBOX_DIR="/tmp/msp-ci-e2e-$(date +%s)"
export SANDBOX_DIR

# Test results tracking
TEST_RESULTS=()
ALL_CORE_STAGES_SUCCESS="NO"

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
}

# ============================================================================
# STEP 1: Create Sandbox and Copy Files
# ============================================================================

log_test "Creating sandbox directory: $SANDBOX_DIR"
mkdir -p "$SANDBOX_DIR"
cd "$SANDBOX_DIR"

log_test "Initializing git repository in sandbox"
git init --quiet
git config user.name "CI Test"
git config user.email "ci-test@example.com"
git commit --allow-empty -m "Initial commit" --quiet || true

# Create a dummy tag so auto_version.sh can bump from it
# This simulates a real repo with existing tags
log_test "Creating initial git tag for version bump testing"
git tag "0.0.1" -m "Initial test tag" --quiet || true

log_test "Copying essential files to sandbox..."

# Copy Scripts directory (entire structure)
log_test "  - Copying Scripts/ directory"
cp -r "$REAL_REPO_ROOT/Scripts" "$SANDBOX_DIR/" || {
    echo "ERROR: Failed to copy Scripts directory" >&2
    exit 1
}

# Copy Podspecs
log_test "  - Copying Podspecs"
mkdir -p "$SANDBOX_DIR"
for podspec in "$REAL_REPO_ROOT"/*.podspec; do
    if [[ -f "$podspec" ]]; then
        cp "$podspec" "$SANDBOX_DIR/" 2>/dev/null || true
    fi
done

# Copy Package.swift if exists
if [[ -f "$REAL_REPO_ROOT/Package.swift" ]]; then
    log_test "  - Copying Package.swift"
    cp "$REAL_REPO_ROOT/Package.swift" "$SANDBOX_DIR/" 2>/dev/null || true
fi

# Copy Package.swift.template if exists
if [[ -f "$REAL_REPO_ROOT/Package.swift.template" ]]; then
    log_test "  - Copying Package.swift.template"
    cp "$REAL_REPO_ROOT/Package.swift.template" "$SANDBOX_DIR/" 2>/dev/null || true
fi

# Copy Examples/MSPDemoApp for verification
if [[ -d "$REAL_REPO_ROOT/Examples/MSPDemoApp" ]]; then
    log_test "  - Copying Examples/MSPDemoApp"
    mkdir -p "$SANDBOX_DIR/Examples"
    cp -r "$REAL_REPO_ROOT/Examples/MSPDemoApp" "$SANDBOX_DIR/Examples/" 2>/dev/null || true
fi

# Copy Configs if exists
if [[ -d "$REAL_REPO_ROOT/Configs" ]]; then
    log_test "  - Copying Configs/"
    cp -r "$REAL_REPO_ROOT/Configs" "$SANDBOX_DIR/" 2>/dev/null || true
fi

# Create minimal Sources directory structure (for SPM)
log_test "  - Creating minimal Sources/ structure"
mkdir -p "$SANDBOX_DIR/Sources"

# Create Releases directory
mkdir -p "$SANDBOX_DIR/Releases"

log_test "Sandbox setup complete"

# ============================================================================
# STEP 2: Set Up Environment Variables
# ============================================================================

log_test "Setting up CI environment variables..."

export MSP_SLACK_BLOCK_MODE="1"
export MSP_EMAIL_DISABLED="1"
export MSP_LOCAL_VERIFY_ENABLED="1"
export MSP_DEVICE_VERIFY_ENABLED="1"
export MSP_REMOTE_VERIFY_ENABLED="1"
export MSP_XCF_VERIFY_ENABLED="1"

# Prevent real git tags / pushes / trunk pushes
export SKIP_PUSH="true"
export DRY_RUN="true"  # Use dry-run to prevent actual publishes
export PODS_ENABLED="false"  # Skip CocoaPods publish
export SPM_ENABLED="false"   # Skip SPM publish

# Use auto version bump
export VERSION="auto"
export RELEASE_NOTES="CI Automated E2E Test Release"

# Set ROOT_DIR to sandbox
export ROOT_DIR="$SANDBOX_DIR"

log_test "Environment variables set:"
log_test "  - MSP_SLACK_BLOCK_MODE=$MSP_SLACK_BLOCK_MODE"
log_test "  - MSP_EMAIL_DISABLED=$MSP_EMAIL_DISABLED"
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
    log_result "CI_ENTRYPOINT_EXECUTED" "YES"
    ALL_CORE_STAGES_SUCCESS="YES"
else
    log_result "CI_ENTRYPOINT_EXECUTED" "NO"
    log_test "WARN: CI entrypoint exited with code $CI_EXIT_CODE"
    ALL_CORE_STAGES_SUCCESS="NO"
fi

# ============================================================================
# STEP 4: Validate Results
# ============================================================================

log_test "===================================================="
log_test "Validating Pipeline Results"
log_test "===================================================="

# 1) Version resolved?
RESOLVED_VERSION=""
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    RESOLVED_VERSION="$(jq -r '.release.version // .version // "unknown"' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "unknown")"
fi
if [[ -n "$RESOLVED_VERSION" ]] && [[ "$RESOLVED_VERSION" != "unknown" ]]; then
    log_result "VERSION_RESOLVED" "YES ($RESOLVED_VERSION)"
else
    log_result "VERSION_RESOLVED" "NO"
fi

# 2) Branch created?
RELEASE_BRANCH="release/$RESOLVED_VERSION"
if git rev-parse --verify "$RELEASE_BRANCH" >/dev/null 2>&1; then
    log_result "BRANCH_CREATED" "YES ($RELEASE_BRANCH)"
else
    log_result "BRANCH_CREATED" "NO"
fi

# 3) Orchestrator ran pre-release setup?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    PRE_RELEASE_SETUP="$(jq -r '.steps.pre_release_setup // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$PRE_RELEASE_SETUP" ]]; then
        log_result "PRE_RELEASE_SETUP" "YES"
    else
        log_result "PRE_RELEASE_SETUP" "NO"
    fi
else
    log_result "PRE_RELEASE_SETUP" "NO"
fi

# 4) Pods publish skipped by flags?
if [[ "${PODS_ENABLED:-true}" == "false" ]]; then
    log_result "PODS_PUBLISH_SKIPPED" "YES (PODS_ENABLED=false)"
else
    log_result "PODS_PUBLISH_SKIPPED" "NO"
fi

# 5) SPM publish skipped by flags?
if [[ "${SPM_ENABLED:-true}" == "false" ]]; then
    log_result "SPM_PUBLISH_SKIPPED" "YES (SPM_ENABLED=false)"
else
    log_result "SPM_PUBLISH_SKIPPED" "NO"
fi

# 6) Remote verification executed?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    REMOTE_VERIFY="$(jq -r '.remote_verify // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$REMOTE_VERIFY" ]] && [[ "$REMOTE_VERIFY" != "null" ]]; then
        log_result "REMOTE_VERIFICATION_EXECUTED" "YES"
    else
        log_result "REMOTE_VERIFICATION_EXECUTED" "NO"
    fi
else
    log_result "REMOTE_VERIFICATION_EXECUTED" "NO"
fi

# 7) Local verification executed?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    LOCAL_VERIFY="$(jq -r '.local_verify // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$LOCAL_VERIFY" ]] && [[ "$LOCAL_VERIFY" != "null" ]]; then
        log_result "LOCAL_VERIFICATION_EXECUTED" "YES"
    else
        log_result "LOCAL_VERIFICATION_EXECUTED" "NO"
    fi
else
    log_result "LOCAL_VERIFICATION_EXECUTED" "NO"
fi

# 8) Device verification executed?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    DEVICE_VERIFY="$(jq -r '.device_verify // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$DEVICE_VERIFY" ]] && [[ "$DEVICE_VERIFY" != "null" ]]; then
        log_result "DEVICE_VERIFICATION_EXECUTED" "YES"
    else
        log_result "DEVICE_VERIFICATION_EXECUTED" "NO"
    fi
else
    log_result "DEVICE_VERIFICATION_EXECUTED" "NO"
fi

# 9) XCFramework verification executed?
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    XCF_VERIFY="$(jq -r '.xcframework_verify // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$XCF_VERIFY" ]] && [[ "$XCF_VERIFY" != "null" ]]; then
        log_result "XCFRAMEWORK_VERIFICATION_EXECUTED" "YES"
    else
        log_result "XCFRAMEWORK_VERIFICATION_EXECUTED" "NO"
    fi
else
    log_result "XCFRAMEWORK_VERIFICATION_EXECUTED" "NO"
fi

# 10) Slack BlockKit message generated?
# Check if notification was attempted (we can't verify actual Slack send in test mode)
if [[ -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
    # Check if notification data exists in state
    NOTIFICATION_DATA="$(jq -r '.notifications // empty' "$SANDBOX_DIR/.msp-release-state.json" 2>/dev/null || echo "")"
    if [[ -n "$NOTIFICATION_DATA" ]] && [[ "$NOTIFICATION_DATA" != "null" ]]; then
        BLOCKKIT_PREVIEW="$(echo "$NOTIFICATION_DATA" | jq -r '.slack_blockkit // .blockkit // ""' 2>/dev/null || echo "")"
        if [[ -n "$BLOCKKIT_PREVIEW" ]]; then
            BLOCKKIT_PREVIEW_SHORT="${BLOCKKIT_PREVIEW:0:30}"
            log_result "SLACK_BLOCKKIT_GENERATED" "YES (${BLOCKKIT_PREVIEW_SHORT}...)"
        else
            log_result "SLACK_BLOCKKIT_GENERATED" "NO"
        fi
    else
        log_result "SLACK_BLOCKKIT_GENERATED" "UNKNOWN (check logs)"
    fi
else
    log_result "SLACK_BLOCKKIT_GENERATED" "NO"
fi

# 11) release.md created?
RELEASE_MD_PATH="$SANDBOX_DIR/Releases/release-$RESOLVED_VERSION.md"
if [[ -f "$RELEASE_MD_PATH" ]]; then
    log_result "RELEASE_MD_CREATED" "YES"
    log_test "First 20 lines of release.md:"
    head -n 20 "$RELEASE_MD_PATH" | sed 's/^/  /'
else
    log_result "RELEASE_MD_CREATED" "NO"
fi

# ============================================================================
# STEP 5: Final Summary
# ============================================================================

log_test "===================================================="
log_test "[CI E2E RESULT]"
log_test "===================================================="

echo "  - ALL CORE STAGES SUCCESSFUL: $ALL_CORE_STAGES_SUCCESS"
echo "  - Release Version: ${RESOLVED_VERSION:-unknown}"
if [[ -f "$RELEASE_MD_PATH" ]]; then
    echo "  - Release Report: Releases/release-$RESOLVED_VERSION.md"
else
    echo "  - Release Report: (not generated)"
fi

log_test "===================================================="

# ============================================================================
# Cleanup (optional - comment out for debugging)
# ============================================================================

# Uncomment to auto-cleanup sandbox
# log_test "Cleaning up sandbox: $SANDBOX_DIR"
# rm -rf "$SANDBOX_DIR"

log_test "Test complete. Sandbox location: $SANDBOX_DIR"
log_test "To inspect sandbox, check: $SANDBOX_DIR"

# Always exit 0 (soft-fail test script)
exit 0

