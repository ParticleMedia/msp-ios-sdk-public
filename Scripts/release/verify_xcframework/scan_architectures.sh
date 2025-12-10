#!/bin/bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
# ============================================================================
# Scan XCFramework Architectures
# ============================================================================
# Purpose: Validate XCFramework contains required architectures
#
# Usage:   ./scan_architectures.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_architectures() {
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
    
    vr_log_info "[XCF] Scanning architectures for $module_name..."
    
    local warnings=0
    local has_arm64=0
    local has_arm64_simulator=0
    local has_x86_64=0
    
    # Check for arm64 (device)
    if [[ -d "$xcframework_path/ios-arm64" ]] || [[ -d "$xcframework_path/ios-arm64_x86_64-simulator" ]]; then
        has_arm64=1
        vr_log_info "[XCF] Found arm64 architecture"
    else
        vr_log_warn "[XCF] Missing arm64 architecture"
        warnings=$((warnings + 1))
    fi
    
    # Check for arm64-simulator
    if [[ -d "$xcframework_path/ios-arm64_x86_64-simulator" ]] || [[ -d "$xcframework_path/ios-arm64-simulator" ]]; then
        has_arm64_simulator=1
        vr_log_info "[XCF] Found arm64-simulator architecture"
    else
        vr_log_warn "[XCF] Missing arm64-simulator architecture (simulator support may be limited)"
        warnings=$((warnings + 1))
    fi
    
    # Check for x86_64 (simulator)
    if [[ -d "$xcframework_path/ios-arm64_x86_64-simulator" ]] || [[ -d "$xcframework_path/ios-x86_64-simulator" ]]; then
        has_x86_64=1
        vr_log_info "[XCF] Found x86_64 architecture"
    else
        vr_log_warn "[XCF] Missing x86_64 architecture (Intel Mac simulator support may be limited)"
        warnings=$((warnings + 1))
    fi
    
    # Use lipo to verify actual binary architectures
    local binary_path=""
    if [[ -d "$xcframework_path/ios-arm64" ]]; then
        binary_path="$(find "$xcframework_path/ios-arm64" -name "$module_name" -type f | head -1)"
    fi
    
    if [[ -n "$binary_path" ]] && [[ -f "$binary_path" ]] && command -v lipo >/dev/null 2>&1; then
        local lipo_info
        lipo_info="$(lipo -info "$binary_path" 2>/dev/null || echo "")"
        if [[ -n "$lipo_info" ]]; then
            vr_log_info "[XCF] Binary architectures: $lipo_info"
        fi
    fi
    
    # Export warnings count
    echo "$warnings"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_architectures "$@"
fi

