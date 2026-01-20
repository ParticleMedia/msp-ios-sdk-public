#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Scan XCFramework Swift Modules
# ============================================================================
# Purpose: Validate Swift module files exist
#
# Usage:   ./scan_swiftmodules.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_swiftmodules() {
    local xcframework_path="$1"
    local module_name="$2"
    
    if [[ -z "$xcframework_path" ]] || [[ ! -d "$xcframework_path" ]]; then
        vr_log_error "[XCF] Invalid XCFramework path: $xcframework_path"
        return 1
    fi
    
    if [[ -z "$module_name" ]]; then
        vr_log_error "[XCF] Module name required"
        return 1
    fi
    
    vr_log_info "[XCF] Scanning Swift modules for $module_name..."
    
    local missing_files=0
    
    # Check for Swift modules in each architecture slice
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")
    
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ ! -d "$slice_path" ]]; then
            continue
        fi
        
        # Check for .swiftinterface
        local swiftinterface_path="$slice_path/$module_name.swiftmodule/$(uname -m).swiftinterface"
        if [[ ! -f "$swiftinterface_path" ]]; then
            # Try alternative path
            swiftinterface_path="$slice_path/$module_name.swiftmodule/arm64-apple-ios.swiftinterface"
            if [[ ! -f "$swiftinterface_path" ]]; then
                swiftinterface_path="$slice_path/$module_name.swiftmodule/x86_64-apple-ios-simulator.swiftinterface"
            fi
        fi
        
        if [[ ! -f "$swiftinterface_path" ]]; then
            vr_log_error "[XCF] Missing .swiftinterface in $slice"
            missing_files=$((missing_files + 1))
        else
            vr_log_info "[XCF] Found .swiftinterface in $slice"
        fi
        
        # Check for .swiftmodule
        local swiftmodule_path="$slice_path/$module_name.swiftmodule/$(uname -m).swiftmodule"
        if [[ ! -f "$swiftmodule_path" ]]; then
            swiftmodule_path="$slice_path/$module_name.swiftmodule/arm64-apple-ios.swiftmodule"
            if [[ ! -f "$swiftmodule_path" ]]; then
                swiftmodule_path="$slice_path/$module_name.swiftmodule/x86_64-apple-ios-simulator.swiftmodule"
            fi
        fi
        
        if [[ ! -f "$swiftmodule_path" ]]; then
            vr_log_warn "[XCF] Missing .swiftmodule in $slice (may be acceptable for interface-only modules)"
        else
            vr_log_info "[XCF] Found .swiftmodule in $slice"
        fi
    done
    
    # If critical files are missing, return failure
    if [[ $missing_files -gt 0 ]]; then
        vr_log_error "[XCF] Missing critical Swift module files (SPM/Pods cannot work)"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_swiftmodules "$@"
fi

