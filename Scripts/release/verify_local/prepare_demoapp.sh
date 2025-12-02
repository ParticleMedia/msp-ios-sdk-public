#!/bin/bash
# ============================================================================
# Prepare DemoApp for Local Verification
# ============================================================================
# Purpose: Copy DemoApp into sandbox directory for local verification
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# Ensure ROOT_DIR is detected
vr_detect_root_dir || {
    vr_log_error "Failed to detect ROOT_DIR"
    return 1
}

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Create DemoApp subdirectory in sandbox
    mkdir -p "$sandbox/DemoApp"
    
    # Copy DemoApp from Examples/MSPDemoApp/
    local demoapp_source="$ROOT_DIR/Examples/MSPDemoApp"
    
    if [[ ! -d "$demoapp_source" ]]; then
        vr_log_error "DemoApp source not found: $demoapp_source"
        return 1
    fi
    
    # Copy Sources directory
    if [[ -d "$demoapp_source/Sources" ]]; then
        cp -R "$demoapp_source/Sources" "$sandbox/DemoApp/"
        vr_log_info "[LOCAL] Copied Sources directory"
    fi
    
    # Copy Resources directory
    if [[ -d "$demoapp_source/Resources" ]]; then
        cp -R "$demoapp_source/Resources" "$sandbox/DemoApp/"
        vr_log_info "[LOCAL] Copied Resources directory"
    fi
    
    # Copy project.yml
    if [[ -f "$demoapp_source/project.yml" ]]; then
        cp "$demoapp_source/project.yml" "$sandbox/DemoApp/"
        vr_log_info "[LOCAL] Copied project.yml"
    fi
    
    vr_log_info "[LOCAL] Copied DemoApp sources to sandbox: $sandbox/DemoApp"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
fi

