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
# Scan XCFramework Dependencies
# ============================================================================
# Purpose: Validate linked dependencies (no private symbols)
#
# Usage:   ./scan_dependencies.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_dependencies() {
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
    
    vr_log_info "[XCF] Scanning dependencies for $module_name..."
    
    if ! command -v otool >/dev/null 2>&1; then
        vr_log_warn "[XCF] otool not found, skipping dependency scan"
        return 0
    fi
    
    # Find binary in first available slice
    local binary_path=""
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")
    
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ -d "$slice_path" ]]; then
            binary_path="$(find "$slice_path" -name "$module_name" -type f | head -1)"
            if [[ -n "$binary_path" ]] && [[ -f "$binary_path" ]]; then
                break
            fi
        fi
    done
    
    if [[ -z "$binary_path" ]] || [[ ! -f "$binary_path" ]]; then
        vr_log_warn "[XCF] Binary not found, skipping dependency scan"
        return 0
    fi
    
    # Scan linked libraries
    local linked_libs
    linked_libs="$(otool -L "$binary_path" 2>/dev/null || echo "")"
    
    if [[ -z "$linked_libs" ]]; then
        vr_log_warn "[XCF] Could not read linked libraries"
        return 0
    fi
    
    # Check for forbidden patterns
    local forbidden_patterns=(
        "/usr/lib/swift"
        "/System/Library/PrivateFrameworks"
        "@rpath/.*Private"
        "UIKit.*Private"
    )
    
    local violations=0
    while IFS= read -r line; do
        for pattern in "${forbidden_patterns[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                vr_log_error "[XCF] Forbidden dependency detected: $line"
                violations=$((violations + 1))
            fi
        done
    done <<< "$linked_libs"
    
    if [[ $violations -gt 0 ]]; then
        vr_log_error "[XCF] Found $violations forbidden dependency violations"
        return 1
    fi
    
    vr_log_info "[XCF] Dependency scan passed (no forbidden dependencies)"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_dependencies "$@"
fi

