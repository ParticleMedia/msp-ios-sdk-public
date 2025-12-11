#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Inject SDK CocoaPods Dependencies for Device Verification
# ============================================================================
# Purpose: Generate Podfile with released SDK modules
#
# Usage:   ./inject_sdk_pods.sh <sandbox_path>
#          (reads from .msp-release-state.json)
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

inject_sdk_pods() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local podfile_path="$demoapp_dir/Podfile"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    
    # Read released modules from state file
    if [[ ! -f "$state_file" ]]; then
        vr_log_warn "[DEVICE] State file not found, skipping Pods injection"
        return 0
    fi
    
    # Extract version from state file
    local version=""
    if command -v jq >/dev/null 2>&1; then
        version="$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")"
    fi
    
    if [[ -z "$version" ]]; then
        vr_log_warn "[DEVICE] Version not found in state file, skipping Pods injection"
        return 0
    fi
    
    # Extract CocoaPods modules (default to common modules)
    local pods_modules=("MSPCore")
    
    # Try to extract from state if available
    if command -v jq >/dev/null 2>&1; then
        # For now, use default list (can be enhanced to read from state)
        pods_modules=("MSPCore")
    fi
    
    # Generate Podfile
    cat > "$podfile_path" <<EOF
platform :ios, '13.0'
use_frameworks!

target 'MSPDemoApp' do
EOF
    
    # Add each module
    local module_list=""
    for module in "${pods_modules[@]}"; do
        echo "  pod '$module', '$version'" >> "$podfile_path"
        if [[ -z "$module_list" ]]; then
            module_list="$module($version)"
        else
            module_list="$module_list, $module($version)"
        fi
    done
    
    cat >> "$podfile_path" <<EOF
end
EOF
    
    vr_log_info "[DEVICE] Injected SDK Pods: $module_list"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_sdk_pods "$@"
fi

