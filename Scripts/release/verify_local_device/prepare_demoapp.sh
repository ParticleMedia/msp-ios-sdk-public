#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Prepare DemoApp for Device Verification
# ============================================================================
# Purpose: Copy DemoApp into sandbox directory for device verification
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

vr_detect_root_dir || {
    vr_log::error "DEVICE" "Failed to detect ROOT_DIR"
    return 1
}

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "DEVICE" "Sandbox path required"
        return 1
    fi
    
    mkdir -p "$sandbox/DemoApp"

    local demoapp_source="$ROOT_DIR/Examples/MSPDemoApp"
    
    if [[ ! -d "$demoapp_source" ]]; then
        vr_log::error "DEVICE" "DemoApp source not found: $demoapp_source"
        return 1
    fi
    
    if [[ -d "$demoapp_source/Sources" ]]; then
        cp -R "$demoapp_source/Sources" "$sandbox/DemoApp/"
        vr_log::info "DEVICE" "[DEVICE] Copied Sources directory"
    fi
    
    if [[ -d "$demoapp_source/Resources" ]]; then
        cp -R "$demoapp_source/Resources" "$sandbox/DemoApp/"
        vr_log::info "DEVICE" "[DEVICE] Copied Resources directory"
    fi
    
    if [[ -f "$demoapp_source/project.yml" ]]; then
        cp "$demoapp_source/project.yml" "$sandbox/DemoApp/"
        vr_log::info "DEVICE" "[DEVICE] Copied project.yml"
    fi
    
    vr_log::info "DEVICE" "[DEVICE] Prepared DemoApp in sandbox: $sandbox/DemoApp"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
fi

