#!/bin/bash
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
    
    local errors=0
    
    # Check Info.plist
    local plist_path="$xcframework_path/Info.plist"
    if [[ ! -f "$plist_path" ]]; then
        vr_log_error "[XCF] Missing Info.plist"
        errors=$((errors + 1))
    else
        vr_log_info "[XCF] Found Info.plist"
        
        # Validate CFBundlePackageType
        if command -v plutil >/dev/null 2>&1; then
            local package_type
            package_type="$(plutil -extract CFBundlePackageType raw "$plist_path" 2>/dev/null || echo "")"
            if [[ "$package_type" != "XFWK" ]]; then
                vr_log_error "[XCF] Invalid CFBundlePackageType: $package_type (expected XFWK)"
                errors=$((errors + 1))
            else
                vr_log_info "[XCF] CFBundlePackageType is correct: XFWK"
            fi
        fi
    fi
    
    # Check umbrella header (at least in one slice)
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
            
            # Check if umbrella header references exist
            if command -v grep >/dev/null 2>&1; then
                local referenced_headers
                referenced_headers="$(grep -E '^#import|<.*\.h>' "$umbrella_path" 2>/dev/null | sed -E 's/.*["<]([^">]+)\.h[">].*/\1.h/' || echo "")"
                
                if [[ -n "$referenced_headers" ]]; then
                    while IFS= read -r header; do
                        local header_path="$slice_path/Headers/$header"
                        if [[ ! -f "$header_path" ]]; then
                            vr_log_warn "[XCF] Umbrella header references missing file: $header"
                        fi
                    done <<< "$referenced_headers"
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
        return 1
    fi
    
    vr_log_info "[XCF] Info.plist and umbrella header validation passed"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_plist "$@"
fi

