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
# Build DemoApp Using SPM
# ============================================================================
# Purpose: Build DemoApp in sandbox using Swift Package Manager
#
# Usage:   ./build_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

build_demoapp_spm() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "SPM" "Sandbox path required"
        return 1
    fi
    
    if [[ ! -d "$sandbox" ]]; then
        vr_log::error "SPM" "Sandbox directory does not exist: $sandbox"
        return 1
    fi
    
    pushd "$sandbox" >/dev/null || {
        vr_log::error "SPM" "Failed to change to sandbox directory"
        return 1
    }
    
    # Step 1: Resolve package dependencies
    vr_log::info "SPM" "[SPM] Running swift package resolve..."
    if ! swift package resolve; then
        vr_log::error "SPM" "[SPM] swift package resolve failed"
        popd >/dev/null
        return 1
    fi
    
    # Step 2: Build the package
    vr_log::info "SPM" "[SPM] Building DemoApp via swift build..."
    if ! swift build --configuration release; then
        vr_log::error "SPM" "[SPM] Swift build failed"
        popd >/dev/null
        return 1
    fi
    
    vr_log::info "SPM" "[SPM] Swift build succeeded"
    
    popd >/dev/null
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    build_demoapp_spm "$@"
fi

