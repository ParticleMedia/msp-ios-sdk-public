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
# Scan XCFramework Symbol Table
# ============================================================================
# Purpose: Validate symbol table (no private/debug symbols leaked)
#
# Usage:   ./scan_symbols.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_symbols() {
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
    
    vr_log_info "[XCF] Scanning symbol table for $module_name..."
    
    if ! command -v nm >/dev/null 2>&1; then
        vr_log_warn "[XCF] nm not found, skipping symbol scan"
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
        vr_log_warn "[XCF] Binary not found, skipping symbol scan"
        return 0
    fi
    
    # Extract global symbols
    local symbols
    symbols="$(nm -gU "$binary_path" 2>/dev/null || echo "")"
    
    if [[ -z "$symbols" ]]; then
        vr_log_warn "[XCF] Could not extract symbols"
        return 0
    fi
    
    # Check for forbidden symbol patterns
    local forbidden_patterns=(
        "_OBJC_CLASS_\$_"
        "__Z"
        "__T"
        "\.debug_"
        "__internal_"
    )
    
    local violations=0
    while IFS= read -r line; do
        for pattern in "${forbidden_patterns[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                vr_log_error "[XCF] Forbidden symbol detected: $line"
                violations=$((violations + 1))
            fi
        done
    done <<< "$symbols"
    
    if [[ $violations -gt 0 ]]; then
        vr_log_error "[XCF] Found $violations forbidden symbol violations"
        return 1
    fi
    
    vr_log_info "[XCF] Symbol scan passed (no forbidden symbols)"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_symbols "$@"
fi

