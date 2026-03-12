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
# Inject SDK CocoaPods Dependencies for Device Verification
# ============================================================================
# Purpose: Generate Podfile with released SDK modules
#
# Usage:   ./inject_sdk_pods.sh <sandbox_path>
#          (reads from .msp-release-state.json)
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

inject_sdk_pods() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "DEVICE" "Sandbox path required"
        return 1
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local podfile_path="$demoapp_dir/Podfile"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    
    if [[ ! -f "$state_file" ]]; then
        vr_log::warn "DEVICE" "[DEVICE] State file not found, skipping Pods injection"
        return 0
    fi
    
    local version=""
    if command -v jq >/dev/null 2>&1; then
        version="$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")"
    fi
    
    if [[ -z "$version" ]]; then
        vr_log::warn "DEVICE" "[DEVICE] Version not found in state file, skipping Pods injection"
        return 0
    fi
    
    local pods_modules=("MSPCore")
    
    # Try to extract from state if available
    if command -v jq >/dev/null 2>&1; then
        # For now, use default list (can be enhanced to read from state)
        pods_modules=("MSPCore")
    fi
    
    cat > "$podfile_path" <<EOF
platform :ios, '13.0'
use_frameworks!

target 'MSPDemoApp' do
EOF
    
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
    
    vr_log::info "DEVICE" "[DEVICE] Injected SDK Pods: $module_list"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_sdk_pods "$@"
fi

