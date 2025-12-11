#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Build DemoApp Using SPM
# ============================================================================
# Purpose: Build DemoApp in sandbox using Swift Package Manager
#
# Usage:   ./build_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

build_demoapp_spm() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    if [[ ! -d "$sandbox" ]]; then
        vr_log_error "Sandbox directory does not exist: $sandbox"
        return 1
    fi
    
    pushd "$sandbox" >/dev/null || {
        vr_log_error "Failed to change to sandbox directory"
        return 1
    }
    
    # Step 1: Resolve package dependencies
    vr_log_info "[SPM] Running swift package resolve..."
    if ! swift package resolve; then
        vr_log_error "[SPM] swift package resolve failed"
        popd >/dev/null
        return 1
    fi
    
    # Step 2: Build the package
    vr_log_info "[SPM] Building DemoApp via swift build..."
    if ! swift build --configuration release; then
        vr_log_error "[SPM] Swift build failed"
        popd >/dev/null
        return 1
    fi
    
    vr_log_info "[SPM] Swift build succeeded"
    
    popd >/dev/null
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    build_demoapp_spm "$@"
fi

