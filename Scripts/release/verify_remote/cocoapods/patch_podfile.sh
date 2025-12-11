#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Patch Podfile for Remote CocoaPods Verification
# ============================================================================
# Purpose: Generate Podfile to use remote source instead of local path
#
# Usage:   ./patch_podfile.sh <sandbox_path>
#          (reads MSP_VERIFY_PODS_URL, MSP_VERIFY_PODS_VERSION from environment)
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

patch_podfile() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Read configuration from environment
    local remote_url="${MSP_VERIFY_PODS_URL:-}"
    local remote_version="${MSP_VERIFY_PODS_VERSION:-}"
    
    if [[ -z "$remote_url" ]] || [[ -z "$remote_version" ]]; then
        vr_log_error "MSP_VERIFY_PODS_URL and MSP_VERIFY_PODS_VERSION required"
        return 1
    fi
    
    # Generate Podfile in sandbox/DemoApp/
    local podfile_path="$sandbox/DemoApp/Podfile"
    
    cat > "$podfile_path" <<EOF
platform :ios, '13.0'
use_frameworks!

target 'MSPDemoApp' do
  pod 'MSP', :git => '$remote_url', :tag => '$remote_version'
end
EOF
    
    vr_log_info "[PODS] Patched Podfile (URL=$remote_url, version=$remote_version)"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    patch_podfile "$@"
fi
