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
# CI Release Preflight Loop Test
# ============================================================================
# Purpose: Continuously execute real release simulations with Preflight
#
# This script:
# - Runs infinite loop of real release simulations
# - Generates unique test version numbers (0.<RANDOM>.<TIMESTAMP>-spm-preflight)
# - Creates isolated sandbox for each iteration
# - Actually publishes to Pods trunk and SPM
# - Pushes branches and tags to remote
# - Validates all pipeline stages
# - Continues on errors (does not exit loop)
#
# Usage: bash Scripts/tests/ci_release_preflight_loop.sh
# Stop: Ctrl+C
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Get real repo root and remote URL
# CRITICAL: REAL_REPO_ROOT must be calculated BEFORE we cd into the sandbox
# Use script-based detection (most reliable when script is in real repo)
# DO NOT use git rev-parse here because it will return sandbox dir if we're already in sandbox
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export REAL_REPO_ROOT

# Verify REAL_REPO_ROOT is correct
if [[ ! -d "$REAL_REPO_ROOT/Scripts" ]]; then
    echo "ERROR: REAL_REPO_ROOT is incorrect: $REAL_REPO_ROOT" >&2
    echo "ERROR: Scripts directory not found at $REAL_REPO_ROOT/Scripts" >&2
    exit 1
fi
if [[ ! -d "$REAL_REPO_ROOT/Scripts/release" ]]; then
    echo "ERROR: Scripts/release directory not found at $REAL_REPO_ROOT/Scripts/release" >&2
    exit 1
fi

# Get git remote URL
GIT_REMOTE_URL="$(cd "$REAL_REPO_ROOT" && git remote get-url origin 2>/dev/null || echo "")"
if [[ -z "$GIT_REMOTE_URL" ]]; then
    echo "ERROR: Could not determine git remote URL" >&2
    exit 1
fi

# Error log file
ERROR_LOG="/tmp/msp-preflight-loop-error.log"

# Loop counter
LOOP_COUNT=0

# ============================================================================
# Helper Functions
# ============================================================================

log_loop() {
    echo "[LOOP] $*" >&2
}

log_error() {
    local msg="$1"
    echo "[ERROR] $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$ERROR_LOG"
}

generate_test_version() {
    # Generate random minor version (1-999)
    RANDOM_MINOR=$((RANDOM % 999 + 1))
    # Get timestamp (YYYYMMDD)
    TIMESTAMP="$(date +%Y%m%d)"
    # Format: 0.<RANDOM_MINOR>.<TIMESTAMP>-spm-preflight
    echo "0.${RANDOM_MINOR}.${TIMESTAMP}-spm-preflight"
}

# ============================================================================
# Signal Handler (Ctrl+C)
# ============================================================================

cleanup_on_exit() {
    echo ""
    log_loop "===================================================="
    log_loop "Preflight Loop Interrupted (Ctrl+C)"
    log_loop "Total iterations: $LOOP_COUNT"
    log_loop "Error log: $ERROR_LOG"
    log_loop "===================================================="
    exit 0
}

trap cleanup_on_exit INT TERM

# ============================================================================
# Enhanced CI Pipeline Wrapper with Full Observability
# ============================================================================
# NOTE: This function must be defined BEFORE the while loop to ensure
#       bash recognizes it when called inside the loop
# ============================================================================
run_ci_pipeline() {
    local ci_log="$SANDBOX_DIR/ci.log"
    local ci_exit=0
    local validate_exit=0
    
    log_loop "[CI] Starting CI pipeline execution..."
    log_loop "[CI] Log file: $ci_log"
    
    
    # Run CI script and capture all output to ci.log
    log_loop "[CI] Executing: bash $CI_ENTRYPOINT"
    if bash "$CI_ENTRYPOINT" > "$ci_log" 2>&1; then
        ci_exit=0
    else
        ci_exit=$?
    fi
    
    log_loop "[CI] Raw exit code: $ci_exit"
    
    # Show last 20 lines of CI log for immediate feedback
    if [[ -f "$ci_log" ]]; then
        log_loop "[CI] Last 20 lines of CI output:"
        tail -n 20 "$ci_log" | while IFS= read -r line; do
            log_loop "  $line"
        done
    fi
    
    # ========================================================================
    # Phase 2: Validation (check for expected artifacts)
    # ========================================================================
    log_loop "[VALIDATE] Starting artifact validation..."
    validate_exit=0
    
    # 1) Check state JSON
    if [[ ! -f "$SANDBOX_DIR/.msp-release-state.json" ]]; then
        log::error "TEST" "[VALIDATE] State JSON not generated"
        validate_exit=100
    else
        log_loop "[VALIDATE] ✓ State JSON exists"
    fi
    
    # 2) Check release.md
    RELEASE_MD_PATH="$SANDBOX_DIR/Releases/release-$TEST_VERSION.md"
    if [[ ! -f "$RELEASE_MD_PATH" ]]; then
        log::error "TEST" "[VALIDATE] Release.md not generated (expected: $RELEASE_MD_PATH)"
        validate_exit=100
    else
        log_loop "[VALIDATE] ✓ Release.md exists: $RELEASE_MD_PATH"
        # Show first few lines of release.md for verification
        log_loop "[VALIDATE] Release.md preview (first 5 lines):"
        head -n 5 "$RELEASE_MD_PATH" | while IFS= read -r line; do
            log_loop "  $line"
        done
    fi
    
    # 3) Check branch push (if CI succeeded)
    RELEASE_BRANCH="release/$TEST_VERSION"
    if [[ $ci_exit -eq 0 ]]; then
        if git ls-remote --heads origin "$RELEASE_BRANCH" >/dev/null 2>&1; then
            log_loop "[VALIDATE] ✓ Release branch pushed: $RELEASE_BRANCH"
        else
            log::error "TEST" "[VALIDATE] Release branch not pushed: $RELEASE_BRANCH"
            validate_exit=100
        fi
    else
        log_loop "[VALIDATE] Skipping branch check (CI exit code: $ci_exit)"
    fi
    
    # 4) Check tag push (if CI succeeded)
    if [[ $ci_exit -eq 0 ]]; then
        # Check for any tags matching the version
        PUSHED_TAGS="$(git ls-remote --tags origin 2>/dev/null | grep -E "refs/tags/.*-${TEST_VERSION}$" || echo "")"
        if [[ -n "$PUSHED_TAGS" ]]; then
            log_loop "[VALIDATE] ✓ Tag pushed: $TEST_VERSION"
        else
            log::error "TEST" "[VALIDATE] Tag not pushed: $TEST_VERSION"
            validate_exit=100
        fi
    else
        log_loop "[VALIDATE] Skipping tag check (CI exit code: $ci_exit)"
    fi
    
    # Summary
    log_loop "[CI] Summary:"
    log_loop "  [ci] raw exit code: $ci_exit"
    log_loop "  [validate] exit code: $validate_exit"
    log_loop "  [validate] release.md: $([[ -f "$RELEASE_MD_PATH" ]] && echo "EXISTS" || echo "MISSING")"
    log_loop "  [validate] branch: $([[ $ci_exit -eq 0 ]] && git ls-remote --heads origin "$RELEASE_BRANCH" >/dev/null 2>&1 && echo "PUSHED" || echo "NOT_PUSHED")"
    log_loop "  [validate] tag: $([[ $ci_exit -eq 0 ]] && git ls-remote --tags origin "$TEST_VERSION" >/dev/null 2>&1 && echo "PUSHED" || echo "NOT_PUSHED")"
    
    # Return validation exit code if validation failed
    if [[ $validate_exit -ne 0 ]]; then
        return 100
    fi
    
    # Return CI exit code
    return $ci_exit
}

# ============================================================================
# Main Loop
# ============================================================================

log_loop "===================================================="
log_loop "Starting Preflight Loop Test"
log_loop "===================================================="
log_loop "Repository: $GIT_REMOTE_URL"
log_loop "Error log: $ERROR_LOG"
log_loop "Press Ctrl+C to stop"
log_loop "===================================================="

# Initialize error log
echo "=== Preflight Loop Error Log ===" > "$ERROR_LOG"
echo "Started: $(date)" >> "$ERROR_LOG"
echo "" >> "$ERROR_LOG"

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    
    log_loop ""
    log_loop "===================================================="
    log_loop "Preflight Loop Iteration #$LOOP_COUNT"
    log_loop "===================================================="
    
    # Generate unique test version
    TEST_VERSION="$(generate_test_version)"
    log_loop "Generated version: $TEST_VERSION"
    
    # Create sandbox directory
    SANDBOX_DIR="/tmp/msp-preflight-${TEST_VERSION}"
    export SANDBOX_DIR
    
    log_loop "Creating sandbox: $SANDBOX_DIR"
    mkdir -p "$SANDBOX_DIR"
    cd "$SANDBOX_DIR"
    
    # Clone repository
    log_loop "Cloning repository..."
    if ! git clone "$GIT_REMOTE_URL" . --quiet 2>>"$ERROR_LOG"; then
        log::error "TEST" "Failed to clone repository for version $TEST_VERSION"
        continue
    fi
    
    # Get current branch from real repo
    CURRENT_BRANCH="$(cd "$REAL_REPO_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    log_loop "Switching to branch: $CURRENT_BRANCH"
    git fetch origin "$CURRENT_BRANCH" --quiet 2>/dev/null || true
    git checkout "$CURRENT_BRANCH" --quiet 2>/dev/null || git checkout -b "$CURRENT_BRANCH" --quiet || true
    
    # Set up environment variables
    log_loop "Setting up environment variables..."
    export MSP_RELEASE_MODE="ci"
    export MSP_SLACK_BLOCK_MODE="1"
    export MSP_EMAIL_DISABLED="1"
    
    # Enable verification systems
    export MSP_LOCAL_VERIFY_ENABLED="1"
    export MSP_DEVICE_VERIFY_ENABLED="1"
    export MSP_REMOTE_VERIFY_ENABLED="1"
    export MSP_XCF_VERIFY_ENABLED="1"
    
    # Enable real publishing (this is a preflight test)
    export PODS_ENABLED="true"
    export SPM_ENABLED="true"
    export SKIP_PUSH="false"
    export DRY_RUN="false"
    
    # Set version and release notes
    export VERSION="$TEST_VERSION"
    export RELEASE_NOTES="Preflight Real Release Simulation - Loop"
    
    # Set ROOT_DIR to sandbox
    export ROOT_DIR="$SANDBOX_DIR"
    
    # Run CI release pipeline with enhanced logging
    log_loop "Running CI release pipeline..."
    CI_ENTRYPOINT="$SANDBOX_DIR/Scripts/release/msp-release-ci.sh"
    
    if [[ ! -f "$CI_ENTRYPOINT" ]]; then
        log::error "TEST" "CI entrypoint not found for version $TEST_VERSION"
        continue
    fi
    
    # Execute enhanced CI pipeline wrapper
    if ! run_ci_pipeline; then
        CI_EXIT_CODE=$?
        log::error "TEST" "CI pipeline failed for version $TEST_VERSION"
        log::error "TEST" "  Exit code: $CI_EXIT_CODE"
        log::error "TEST" "  Full log: $SANDBOX_DIR/ci.log"
        # Copy CI log to error log
        if [[ -f "$SANDBOX_DIR/ci.log" ]]; then
            echo "=== CI Log for $TEST_VERSION ===" >> "$ERROR_LOG"
            cat "$SANDBOX_DIR/ci.log" >> "$ERROR_LOG"
            echo "=== End CI Log ===" >> "$ERROR_LOG"
        fi
    else
        CI_EXIT_CODE=0
        log_loop "CI pipeline completed successfully"
    fi
    
    # Legacy validation (kept for compatibility, but now handled in wrapper)
    VALIDATION_PASSED="YES"
    VALIDATION_ERRORS=()
    
    if [[ $CI_EXIT_CODE -ne 0 ]]; then
        VALIDATION_PASSED="NO"
        VALIDATION_ERRORS+=("CI pipeline failed (exit code: $CI_EXIT_CODE)")
    fi
    
    # Print summary
    log_loop "===================================================="
    if [[ $CI_EXIT_CODE -eq 0 ]] && [[ "$VALIDATION_PASSED" == "YES" ]]; then
        log_loop "Preflight Loop: SUCCESS"
    else
        log_loop "Preflight Loop: FAILED"
        if [[ $CI_EXIT_CODE -ne 0 ]]; then
            log_loop "  - CI pipeline exit code: $CI_EXIT_CODE"
        fi
        for err in "${VALIDATION_ERRORS[@]}"; do
            log_loop "  - $err"
        done
    fi
    
    log_loop "Version: $TEST_VERSION"
    if [[ $CI_EXIT_CODE -eq 0 ]]; then
        log_loop "Branch: release/$TEST_VERSION"
        # Extract tag names
        PUSHED_TAGS="${PUSHED_TAGS:-}"
        if [[ -n "$PUSHED_TAGS" ]]; then
            TAG_NAMES="$(echo "$PUSHED_TAGS" | sed 's|.*refs/tags/||' | tr '\n' ' ')"
            log_loop "Tag(s): $TAG_NAMES"
        else
            log_loop "Tag(s): (none)"
        fi
    else
        log_loop "Branch: (not created)"
        log_loop "Tag(s): (not created)"
    fi
    log_loop "Sandbox: $SANDBOX_DIR"
    log_loop "===================================================="
    
    # Continue to next iteration (even on failure)
    log_loop "Continuing to next iteration..."
    sleep 2  # Small delay between iterations
    
done

