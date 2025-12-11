#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# MSP iOS SDK Release System - CI Entrypoint
# ============================================================================
# Purpose: Non-interactive CI release mode for Jenkins / GitHub Actions / CI
#
# Usage:
#   export VERSION="1.9.0"
#   export RELEASE_NOTES="Release notes here"
#   bash Scripts/release/msp-release-ci.sh
#
# Environment Variables:
#   VERSION          - Release version (required, or "auto" for auto-bump)
#   RELEASE_NOTES    - Release notes (optional, "auto" for auto-generate)
#   BASE_BRANCH      - Base branch (optional, defaults to current branch)
#   RELEASE_BRANCH   - Release branch (optional, defaults to release/$VERSION)
#   MSP_EMAIL_DISABLED - Set to "1" to disable email notifications
#   MSP_SLACK_ALERT_ENV - Set to "test" or "prod" (defaults to "test")
# ============================================================================

set -euo pipefail

# ============================================================================
# Release mode: CI
# ============================================================================
# CI mode: always set to "ci", no external override allowed
export MSP_RELEASE_MODE="ci"
echo "[MSP][CI] Release mode: ${MSP_RELEASE_MODE}"

# ============================================================================
# STEP 1 — Determine ROOT_DIR
# ============================================================================

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
export ROOT_DIR

echo "[CI] MSP Release CI Mode"
echo "[CI] ROOT_DIR: $ROOT_DIR"

# ============================================================================
# STEP 2 — Parse CI Environment
# ============================================================================

# ============================================================================
# Fail-Fast Detection for Silent Failures
# ============================================================================
if [[ -z "${VERSION:-}" ]]; then
    echo "[CI][FATAL] VERSION is empty — CI cannot continue" >&2
    echo "Usage: export VERSION=\"1.9.0\" && bash $0" >&2
    echo "   or: export VERSION=\"auto\" && bash $0  (auto-bump patch version)" >&2
    exit 90
fi

if [[ -z "${RELEASE_BRANCH:-}" ]] && [[ -n "${VERSION:-}" ]]; then
    # RELEASE_BRANCH will be auto-generated, but we validate VERSION is set
    : # OK, will be set later
fi

if [[ "$VERSION" == "auto" ]] || [[ "$VERSION" =~ ^auto: ]]; then
    # Use auto_version.sh for version bumping
    AUTO_VERSION_SCRIPT="$ROOT_DIR/Scripts/release/auto_version.sh"
    if [[ -f "$AUTO_VERSION_SCRIPT" ]]; then
        VERSION="$(bash "$AUTO_VERSION_SCRIPT" "$VERSION" 2>/dev/null || echo "")"
        if [[ -z "$VERSION" ]]; then
            echo "Error: Failed to resolve auto version" >&2
            exit 1
        fi
        echo "[CI] Auto-bumped version: $VERSION"
    else
        echo "Error: auto_version.sh not found at $AUTO_VERSION_SCRIPT" >&2
        exit 1
    fi
fi

# RELEASE_NOTES rules
if [[ -z "${RELEASE_NOTES:-}" ]]; then
    RELEASE_NOTES="No release notes provided (CI mode)."
elif [[ "$RELEASE_NOTES" == "auto" ]]; then
    RELEASE_NOTES="Automated CI Release for $VERSION"
fi

# BASE_BRANCH rules
if [[ -z "${BASE_BRANCH:-}" ]]; then
    BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
fi

# RELEASE_BRANCH rules
if [[ -z "${RELEASE_BRANCH:-}" ]]; then
    RELEASE_BRANCH="release/$VERSION"
fi

# Fail-fast: validate RELEASE_BRANCH is set after auto-generation
if [[ -z "${RELEASE_BRANCH:-}" ]]; then
    echo "[CI][FATAL] RELEASE_BRANCH is empty after auto-generation" >&2
    exit 91
fi

echo "[CI] Version: $VERSION"
echo "[CI] Base Branch: $BASE_BRANCH"
echo "[CI] Release Branch: $RELEASE_BRANCH"
echo "[CI] Release Notes: ${RELEASE_NOTES:0:50}${RELEASE_NOTES:50:+...}"

# ============================================================================
# STEP 3 — Export CI Environment Variables
# ============================================================================

export MSP_RELEASE_MODE="ci"
export MSP_SLACK_BLOCK_MODE="${MSP_SLACK_BLOCK_MODE:-1}"
export MSP_EMAIL_DISABLED="${MSP_EMAIL_DISABLED:-0}"
export MSP_SLACK_ALERT_ENV="${MSP_SLACK_ALERT_ENV:-test}"

# Pass version, notes, branches to orchestrator
export RELEASE_VERSION="$VERSION"
export RELEASE_NOTES="$RELEASE_NOTES"
export BASE_BRANCH="$BASE_BRANCH"
export RELEASE_BRANCH="$RELEASE_BRANCH"

# CI-specific variables (for future use)
export MSP_CI_VERSION="$VERSION"
export MSP_CI_RELEASE_NOTES="$RELEASE_NOTES"
export MSP_CI_BASE_BRANCH="$BASE_BRANCH"
export MSP_CI_RELEASE_BRANCH="$RELEASE_BRANCH"

# CI mode: always non-dry-run, always push
export DRY_RUN="false"
export SKIP_PUSH="false"

echo "[CI] MSP_SLACK_BLOCK_MODE=${MSP_SLACK_BLOCK_MODE}"
echo "[CI] MSP_SLACK_ALERT_ENV=${MSP_SLACK_ALERT_ENV}"

# ============================================================================
# STEP 4 — Run Main Release Orchestrator
# ============================================================================

ORCHESTRATOR_SCRIPT="$ROOT_DIR/Scripts/release/orchestrator/modular.sh"

if [[ ! -f "$ORCHESTRATOR_SCRIPT" ]]; then
    echo "Error: Orchestrator script not found: $ORCHESTRATOR_SCRIPT" >&2
    exit 1
fi

echo "[CI] Running release orchestrator..."
echo "[CI] ===================================================="

# Call orchestrator - hard fail on any error (CI requirement)
# Note: orchestrator uses environment variables (RELEASE_VERSION, etc.) which we've already set
# DO NOT pass --version flag as it conflicts with orchestrator's version display command
# Orchestrator will read RELEASE_VERSION from environment
bash "$ORCHESTRATOR_SCRIPT" || {
    ORCHESTRATOR_EXIT_CODE=$?
    echo "[CI] ===================================================="
    echo "[CI] ERROR: Release orchestrator failed with exit code $ORCHESTRATOR_EXIT_CODE" >&2
    echo "[CI] CI Release aborted." >&2
    exit $ORCHESTRATOR_EXIT_CODE
}

echo "[CI] ===================================================="
echo "[CI] Release orchestrator completed successfully"

# ============================================================================
# STEP 5 — Generate Markdown Report
# ============================================================================

REPORT_GENERATOR="$ROOT_DIR/Scripts/release/generate_release_md.sh"
STATE_FILE="$ROOT_DIR/.msp-release-state.json"
REPORT_FILE="$ROOT_DIR/Releases/release-$VERSION.md"

if [[ ! -f "$REPORT_GENERATOR" ]]; then
    echo "[CI] WARN: Report generator not found: $REPORT_GENERATOR" >&2
else
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "[CI] WARN: State file not found: $STATE_FILE" >&2
    else
        echo "[CI] Generating release report..."
        bash "$REPORT_GENERATOR" \
            --state-file "$STATE_FILE" \
            --output "$REPORT_FILE" \
            || echo "[CI] WARN: Report generation failed (soft-fail)" >&2
        
        if [[ -f "$REPORT_FILE" ]]; then
            echo "[CI] Release report generated: Releases/release-$VERSION.md"
        fi
    fi
fi

# ============================================================================
# STEP 6 — Slack + Email Notifications
# ============================================================================

# Notifications are already triggered by the orchestrator
# No need to call notify::send_release_summary manually
echo "[CI] Notification system triggered by orchestrator."

# ============================================================================
# STEP 7 — Final CI Summary
# ============================================================================

echo "===================================================="
echo "[CI] MSP Release CI completed successfully."
echo "[CI] Version: $VERSION"
echo "[CI] Branch:  $RELEASE_BRANCH"
if [[ -f "$REPORT_FILE" ]]; then
    echo "[CI] Report:  Releases/release-$VERSION.md"
else
    echo "[CI] Report:  (not generated)"
fi
echo "===================================================="

exit 0

