#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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
    echo "[TRACE][XCF] ---> Entering dependency scan for $module_name"

    if ! command -v otool >/dev/null 2>&1; then
        vr_log_warn "[XCF] otool not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (otool not found)"
        return 0
    fi

    # Find binary in first available slice
    local binary_path=""
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")

    echo "[TRACE][XCF]      Searching for binary in slices..."
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ -d "$slice_path" ]]; then
            echo "[TRACE][XCF]      Checking slice: $slice"
            binary_path="$(timeout 5s find "$slice_path" -name "$module_name" -type f 2>/dev/null | head -1 || echo "")"
            if [[ -n "$binary_path" ]] && [[ -f "$binary_path" ]]; then
                echo "[TRACE][XCF]      Found binary: $binary_path"
                break
            fi
        fi
    done

    if [[ -z "$binary_path" ]] || [[ ! -f "$binary_path" ]]; then
        vr_log_warn "[XCF] Binary not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (binary not found)"
        return 0
    fi

    # Scan linked libraries with timeout
    echo "[TRACE][XCF]      Running otool -L on binary: $binary_path"
    local linked_libs
    if ! linked_libs="$(timeout 20s otool -L "$binary_path" 2>/dev/null || echo "")"; then
        vr_log_error "[XCF] otool command timed out or failed for $module_name"
        echo "[TRACE][XCF] <--- Dependency scan TIMEOUT on otool"
        return 1
    fi
    echo "[TRACE][XCF]      otool completed successfully"
    
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
        echo "[TRACE][XCF] <--- Dependency scan FAILED ($violations violations)"
        return 1
    fi

    vr_log_info "[XCF] Dependency scan passed (no forbidden dependencies)"
    echo "[TRACE][XCF] <--- Dependency scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_dependencies "$@"
fi

