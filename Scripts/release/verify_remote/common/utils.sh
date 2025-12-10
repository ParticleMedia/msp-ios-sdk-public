#!/bin/bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
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

# ============================================================================
# ROOT_DIR Detection
# ============================================================================

vr_detect_root_dir() {
    # If ROOT_DIR is already set, respect it
    if [[ -n "${ROOT_DIR:-}" ]]; then
        return 0
    fi
    
    # Try git rev-parse --show-toplevel
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
    vr_log_error "Failed to detect repository root directory"
    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

export -f vr_log_info vr_log_warn vr_log_error vr_detect_root_dir 2>/dev/null || true

