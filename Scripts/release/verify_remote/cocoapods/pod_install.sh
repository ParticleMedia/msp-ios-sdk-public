#!/bin/bash
# ============================================================================
# Execute pod install in Sandbox
# ============================================================================
# Purpose: Run pod install in isolated sandbox directory
#
# Usage:   ./pod_install.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

run_pod_install() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Check if pod command exists
    if ! command -v pod >/dev/null 2>&1; then
        vr_log_warn "pod command not found, skipping CocoaPods verification"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local podfile="$demoapp_dir/Podfile"
    
    if [[ ! -f "$podfile" ]]; then
        vr_log_error "Podfile not found: $podfile"
        return 1
    fi
    
    # Create log file in sandbox for pod install output (persisted for debugging)
    local pod_log
    pod_log="$sandbox/pod_install.log"
    mkdir -p "$sandbox" || true
    
    # Change to DemoApp directory and run pod install
    pushd "$demoapp_dir" >/dev/null || {
        vr_log_error "Failed to change to DemoApp directory: $demoapp_dir"
        return 1
    }
    
    vr_log_info "[PODS] Running pod install..."
    if pod install --project-directory=. >"$pod_log" 2>&1; then
        vr_log_info "[PODS] pod install succeeded"
        
        # Verify expected outputs
        if [[ -d "$demoapp_dir/MSPDemoApp.xcworkspace" ]] && [[ -d "$demoapp_dir/Pods" ]]; then
            vr_log_info "[PODS] Workspace and Pods directory created successfully"
        else
            vr_log_warn "[PODS] Workspace or Pods directory missing after pod install"
        
        vr_log_info "[PODS] Pod install log saved to: $pod_log"
        fi
        
        popd >/dev/null
        return 0
    else
        vr_log_error "[PODS] pod install failed (see diagnostics below)"
        echo "------ Full pod install log at: $pod_log ------"
        cat "$pod_log"
        echo "------------------------------------------------"
        popd >/dev/null
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_pod_install "$@"
fi
