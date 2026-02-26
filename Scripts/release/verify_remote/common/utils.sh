#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Remote Verification Common Utilities
# ============================================================================
# Purpose: Shared utility functions for remote release verification
#
# Usage:   source "$(dirname "$0")/utils.sh"
# ============================================================================

set -euo pipefail

# ============================================================================
# Logging Functions
# ============================================================================

vr_log_info() {
    echo "[VR][INFO]  $*" >&1
}

vr_log_warn() {
    echo "[VR][WARN]  $*" >&1
}

vr_log_error() {
    echo "[VR][ERROR] $*" >&2
}

# Double-colon aliases used by verification scripts
vr_log::info()  { vr_log_info "$@"; }
vr_log::warn()  { vr_log_warn "$@"; }
vr_log::error() { vr_log_error "$@"; }

# ============================================================================
# ROOT_DIR Detection
# ============================================================================

vr_detect_root_dir() {
    # If ROOT_DIR is already set, respect it
    if [[ -n "${ROOT_DIR:-}" ]]; then
        return 0
    fi
    
    if command -v git >/dev/null 2>&1; then
        local git_root
        git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            export ROOT_DIR="$git_root"
            return 0
        fi
    fi
    
    # Fallback: walk up until finding Scripts/ folder, then go one level up
    local current_dir
    current_dir="$(pwd)"
    
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/Scripts" ]]; then
            export ROOT_DIR="$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # If we get here, we failed to find the root
    vr_log::error "REMOTE" "Failed to detect repository root directory"
    return 1
}

# ============================================================================
# Toolchain Helpers
# ============================================================================

vr_find_devtool() {
    local tool="$1"

    # Prefer active Xcode toolchain binaries for reproducibility.
    if command -v xcrun >/dev/null 2>&1; then
        local tool_path
        tool_path="$(xcrun --find "$tool" 2>/dev/null || true)"
        if [[ -n "$tool_path" ]] && [[ -x "$tool_path" ]]; then
            echo "$tool_path"
            return 0
        fi
    fi

    command -v "$tool" 2>/dev/null || true
}

vr_run_with_timeout() {
    local seconds="$1"
    shift

    local cmd_name="${1:-}"
    local timeout_bin=""
    if [[ -n "${MSP_TIMEOUT_CMD:-}" ]] && command -v "${MSP_TIMEOUT_CMD}" >/dev/null 2>&1; then
        timeout_bin="$(command -v "${MSP_TIMEOUT_CMD}")"
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_bin="$(command -v gtimeout)"
    elif command -v timeout >/dev/null 2>&1; then
        timeout_bin="$(command -v timeout)"
    fi

    # timeout(1) cannot execute shell functions directly.
    if [[ -n "$timeout_bin" ]] && ! declare -F "$cmd_name" >/dev/null 2>&1; then
        "$timeout_bin" "${seconds}s" "$@"
        return $?
    fi

    # Fallback for environments without timeout(1) (e.g. default macOS).
    "$@"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f vr_log_info vr_log_warn vr_log_error \
         vr_log::info vr_log::warn vr_log::error \
         vr_detect_root_dir \
         vr_find_devtool vr_run_with_timeout 2>/dev/null || true
