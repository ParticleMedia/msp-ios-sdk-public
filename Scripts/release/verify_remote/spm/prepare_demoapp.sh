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
# Prepare DemoApp for SPM Verification
# ============================================================================
# Purpose: Copy DemoApp into sandbox directory for SPM verification
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

vr_detect_root_dir || {
    vr_log::error "SPM" "Failed to detect ROOT_DIR"
    return 1
}

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "SPM" "Sandbox path required"
        return 1
    fi
    
    # 1. Create sandbox subfolder for DemoApp
    mkdir -p "$sandbox/DemoApp"
    
    # 2. Copy the DemoApp project template from $ROOT_DIR/Examples/MSPDemoApp/
    # Must copy: project.yml, Sources/*, Resources/*
    # DO NOT copy: DerivedData, build/, Pods/, xcworkspace
    
    local demoapp_source="$ROOT_DIR/Examples/MSPDemoApp"
    
    if [[ ! -d "$demoapp_source" ]]; then
        vr_log::error "SPM" "DemoApp source not found: $demoapp_source"
        return 1
    fi
    
    if [[ -d "$demoapp_source/Sources" ]]; then
        cp -R "$demoapp_source/Sources" "$sandbox/DemoApp/"
        vr_log::info "SPM" "[SPM] Copied Sources directory"
    fi
    
    if [[ -d "$demoapp_source/Resources" ]]; then
        cp -R "$demoapp_source/Resources" "$sandbox/DemoApp/"
        vr_log::info "SPM" "[SPM] Copied Resources directory"
    fi
    
    if [[ -f "$demoapp_source/project.yml" ]]; then
        cp "$demoapp_source/project.yml" "$sandbox/DemoApp/"
        vr_log::info "SPM" "[SPM] Copied project.yml"
    fi
    
    vr_log::info "SPM" "[SPM] Prepared DemoApp in sandbox: $sandbox/DemoApp"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
fi

