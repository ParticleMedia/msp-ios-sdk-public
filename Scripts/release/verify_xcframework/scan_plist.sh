#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Scan XCFramework Info.plist and Umbrella Headers
# ============================================================================
# Purpose: Validate Info.plist and umbrella header structure
#
# Usage:   ./scan_plist.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_plist() {
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
    
    vr_log_info "[XCF] Scanning Info.plist and umbrella headers for $module_name..."
    echo "[TRACE][XCF] ---> Entering plist scan for $module_name"

    local errors=0

    # Check Info.plist
    echo "[TRACE][XCF]      Checking Info.plist..."
    local plist_path="$xcframework_path/Info.plist"
    if [[ ! -f "$plist_path" ]]; then
        vr_log_error "[XCF] Missing Info.plist"
        errors=$((errors + 1))
    else
        vr_log_info "[XCF] Found Info.plist"

        # Validate CFBundlePackageType with timeout
        if command -v plutil >/dev/null 2>&1; then
            echo "[TRACE][XCF]      Running plutil on Info.plist..."
            local package_type
            if ! package_type="$(timeout 10s plutil -extract CFBundlePackageType raw "$plist_path" 2>/dev/null || echo "")"; then
                vr_log_error "[XCF] plutil command timed out"
                echo "[TRACE][XCF]      plutil TIMEOUT"
                errors=$((errors + 1))
            elif [[ "$package_type" != "XFWK" ]]; then
                vr_log_error "[XCF] Invalid CFBundlePackageType: $package_type (expected XFWK)"
                errors=$((errors + 1))
            else
                vr_log_info "[XCF] CFBundlePackageType is correct: XFWK"
                echo "[TRACE][XCF]      plutil completed successfully"
            fi
        fi
    fi

    # Check umbrella header (at least in one slice)
    echo "[TRACE][XCF]      Checking umbrella headers..."
    local umbrella_found=0
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")

    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ ! -d "$slice_path" ]]; then
            continue
        fi

        local umbrella_path="$slice_path/Headers/$module_name.h"
        if [[ -f "$umbrella_path" ]]; then
            umbrella_found=1
            vr_log_info "[XCF] Found umbrella header in $slice"
            echo "[TRACE][XCF]      Found umbrella: $umbrella_path"

            # Check if umbrella header references exist (with protection against infinite loops)
            if command -v grep >/dev/null 2>&1; then
                echo "[TRACE][XCF]      Scanning umbrella header references..."
                local referenced_headers
                if ! referenced_headers="$(timeout 10s grep -E '^#import|<.*\.h>' "$umbrella_path" 2>/dev/null | sed -E 's/.*["<]([^">]+)\.h[">].*/\1.h/' || echo "")"; then
                    vr_log_warn "[XCF] grep command timed out on umbrella header"
                    echo "[TRACE][XCF]      grep TIMEOUT on umbrella header"
                else
                    if [[ -n "$referenced_headers" ]]; then
                        local iteration_count=0
                        while IFS= read -r header && [[ $iteration_count -lt 1000 ]]; do
                            iteration_count=$((iteration_count + 1))
                            local header_path="$slice_path/Headers/$header"
                            if [[ ! -f "$header_path" ]]; then
                                vr_log_warn "[XCF] Umbrella header references missing file: $header"
                            fi
                        done <<< "$referenced_headers"
                        echo "[TRACE][XCF]      Processed $iteration_count header references"
                    fi
                fi
            fi
            break
        fi
    done
    
    if [[ $umbrella_found -eq 0 ]]; then
        vr_log_error "[XCF] Missing umbrella header (Headers/$module_name.h)"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        vr_log_error "[XCF] Found $errors critical errors in plist/umbrella validation"
        echo "[TRACE][XCF] <--- Plist scan FAILED ($errors errors)"
        return 1
    fi

    vr_log_info "[XCF] Info.plist and umbrella header validation passed"
    echo "[TRACE][XCF] <--- Plist scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_plist "$@"
fi

