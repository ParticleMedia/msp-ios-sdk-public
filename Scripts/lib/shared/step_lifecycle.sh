#!/usr/bin/env bash
# ============================================================================
# Shared Step Lifecycle Module
# ============================================================================
# Module: shared/step_lifecycle.sh
# Purpose: Unified step lifecycle management for release orchestration
#
# Functions:
#   - step_start: Log and mark step as started
#   - step_done: Log and mark step as successful
#   - step_fail: Log and mark step as failed
#   - step_skip: Log and mark step as skipped
#   - mark_step_start/success/error/skipped: State management wrappers
#
# Dependencies:
#   - state.sh (optional - for state persistence)
#   - Logging functions (log::info, log::error, etc.)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_STEP_LIFECYCLE_SOURCED:-}" ]] && return 0
readonly _SHARED_STEP_LIFECYCLE_SOURCED=1

# ============================================================================
# CI-Style Step Logging
# ============================================================================

# Log step start (CI-style)
step() {
    local msg="$1"
    echo "[CI][STEP] $msg..." >&2
}

# Log step done (CI-style)
step_done() {
    local msg="$1"
    echo "[CI][STEP] $msg: OK" >&2
}

# Log step failed (CI-style)
step_fail() {
    local msg="$1"
    local code="${2:-1}"
    echo "[CI][STEP] $msg: FAILED (code=$code)" >&2
}

# Log step skipped with reason (CI-style)
# Format: "step_name (reason)"
step_skip() {
    local full_msg="$1"
    echo "[CI][STEP] $full_msg: SKIPPED" >&2

    # Extract step name and reason from format: "step_name (reason)"
    if [[ "$full_msg" =~ ^([a-z_]+)[[:space:]]*\((.+)\)[[:space:]]*$ ]]; then
        local step_name="${BASH_REMATCH[1]}"
        local reason="${BASH_REMATCH[2]}"

        # Record in state.json if function available
        if command -v msp_state_mark_step_skipped &>/dev/null; then
            msp_state_mark_step_skipped "$step_name" "$reason"
        fi
    fi
}

# ============================================================================
# State Management Wrappers
# ============================================================================
# These wrap state.sh functions if available, otherwise no-op

mark_step_start() {
    local step="$1"
    if command -v msp_state_mark_step_running &>/dev/null; then
        msp_state_mark_step_running "$step"
    fi
}

mark_step_success() {
    local step="$1"
    if command -v msp_state_mark_step_success &>/dev/null; then
        msp_state_mark_step_success "$step"
    fi
}

mark_step_error() {
    local step="$1"
    local reason="${2:-unknown error}"
    if command -v msp_state_mark_step_failed &>/dev/null; then
        msp_state_mark_step_failed "$step" "$reason"
    fi
}

mark_step_skipped() {
    local step="$1"
    local reason="${2:-skipped}"
    if command -v msp_state_mark_step_skipped &>/dev/null; then
        msp_state_mark_step_skipped "$step" "$reason"
    fi
}

# ============================================================================
# Combined Step Lifecycle Functions
# ============================================================================

# Start a step: log and mark as running
# Usage: lifecycle_step_start "step_name" "Human readable description"
lifecycle_step_start() {
    local step_name="$1"
    local description="${2:-$step_name}"

    step "$description"
    mark_step_start "$step_name"
    export CURRENT_STEP="$step_name"
}

# Complete a step successfully
# Usage: lifecycle_step_done "step_name" "Human readable description"
lifecycle_step_done() {
    local step_name="$1"
    local description="${2:-$step_name}"

    step_done "$description"
    mark_step_success "$step_name"
}

# Fail a step
# Usage: lifecycle_step_fail "step_name" "Human readable description" "exit_code" "reason"
lifecycle_step_fail() {
    local step_name="$1"
    local description="${2:-$step_name}"
    local exit_code="${3:-1}"
    local reason="${4:-failed}"

    step_fail "$description" "$exit_code"
    mark_step_error "$step_name" "$reason"
}

# Skip a step
# Usage: lifecycle_step_skip "step_name" "reason"
lifecycle_step_skip() {
    local step_name="$1"
    local reason="${2:-skipped}"

    step_skip "$step_name ($reason)"
    mark_step_skipped "$step_name" "$reason"
}

# ============================================================================
# Fail-Fast Helper
# ============================================================================
# Fail a step and exit immediately
# Usage: fail_step "step_name" "error message" [exit_code]

fail_step() {
    local step_name="$1"
    local message="$2"
    local exit_code="${3:-1}"

    if command -v log::error &>/dev/null; then
        log::error "STEP" "[$step_name] $message"
    else
        echo "[ERROR][$step_name] $message" >&2
    fi

    mark_step_error "$step_name" "$message"
    exit "$exit_code"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f step step_done step_fail step_skip 2>/dev/null || true
export -f mark_step_start mark_step_success mark_step_error mark_step_skipped 2>/dev/null || true
export -f lifecycle_step_start lifecycle_step_done lifecycle_step_fail lifecycle_step_skip 2>/dev/null || true
export -f fail_step 2>/dev/null || true
