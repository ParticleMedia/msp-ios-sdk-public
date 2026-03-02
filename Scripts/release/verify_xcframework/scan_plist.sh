#!/usr/bin/env bash
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

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_plist() {
    local xcframework_path="$1"
    local module_name="$2"
    
    if [[ -z "$xcframework_path" ]] || [[ ! -d "$xcframework_path" ]]; then
        vr_log::error "VERIFY" "[XCF] Invalid XCFramework path: $xcframework_path"
        return 1
    fi
    
    if [[ -z "$module_name" ]]; then
        vr_log::error "VERIFY" "[XCF] Module name required"
        return 1
    fi
    
    vr_log::info "VERIFY" "[XCF] Scanning Info.plist and umbrella headers for $module_name..."
    echo "[TRACE][XCF] ---> Entering plist scan for $module_name"

    local errors=0

    echo "[TRACE][XCF]      Checking Info.plist..."
    local plist_path="$xcframework_path/Info.plist"
    if [[ ! -f "$plist_path" ]]; then
        vr_log::error "VERIFY" "[XCF] Missing Info.plist"
        errors=$((errors + 1))
    else
        vr_log::info "VERIFY" "[XCF] Found Info.plist"

        if command -v plutil >/dev/null 2>&1; then
            echo "[TRACE][XCF]      Running plutil on Info.plist..."
            local package_type
            if ! package_type="$(timeout 10s plutil -extract CFBundlePackageType raw "$plist_path" 2>/dev/null || echo "")"; then
                vr_log::error "VERIFY" "[XCF] plutil command timed out"
                echo "[TRACE][XCF]      plutil TIMEOUT"
                errors=$((errors + 1))
            elif [[ "$package_type" != "XFWK" ]]; then
                vr_log::error "VERIFY" "[XCF] Invalid CFBundlePackageType: $package_type (expected XFWK)"
                errors=$((errors + 1))
            else
                vr_log::info "VERIFY" "[XCF] CFBundlePackageType is correct: XFWK"
                echo "[TRACE][XCF]      plutil completed successfully"
            fi
        fi
    fi

    # Check slice framework Info.plist keys
    # Apple upload validation requires CFBundleShortVersionString + CFBundleVersion
    # for embedded frameworks.
    local slice_plist_errors=0
    local scanned_frameworks=0
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")

    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ ! -d "$slice_path" ]]; then
            continue
        fi

        local found_framework_in_slice=0
        while IFS= read -r -d '' slice_framework; do
            found_framework_in_slice=1
            scanned_frameworks=$((scanned_frameworks + 1))

            local framework_name
            framework_name="$(basename "$slice_framework" .framework)"

            local fw_plist="$slice_framework/Info.plist"
            if [[ -f "$fw_plist" ]] && command -v plutil >/dev/null 2>&1; then
                local short_version
                short_version="$(plutil -extract CFBundleShortVersionString raw "$fw_plist" 2>/dev/null || echo "")"
                local bundle_version
                bundle_version="$(plutil -extract CFBundleVersion raw "$fw_plist" 2>/dev/null || echo "")"

                if [[ -z "$short_version" ]]; then
                    vr_log_error "[XCF] Missing CFBundleShortVersionString in slice: $slice ($framework_name)"
                    slice_plist_errors=$((slice_plist_errors + 1))
                fi

                if [[ -z "$bundle_version" ]]; then
                    vr_log_error "[XCF] Missing CFBundleVersion in slice: $slice ($framework_name)"
                    slice_plist_errors=$((slice_plist_errors + 1))
                fi
            fi
        done < <(find "$slice_path" -maxdepth 1 -type d -name "*.framework" -print0 2>/dev/null)

        if [[ $found_framework_in_slice -eq 0 ]]; then
            vr_log_warn "[XCF] No framework found in slice: $slice"
            slice_plist_errors=$((slice_plist_errors + 1))
        fi
    done

    if [[ $slice_plist_errors -gt 0 ]]; then
        errors=$((errors + slice_plist_errors))
    fi

    # Check umbrella header (best-effort warning only for ObjC-style frameworks).
    echo "[TRACE][XCF]      Checking umbrella headers..."
    local umbrella_found=0
    slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")

    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ ! -d "$slice_path" ]]; then
            continue
        fi

        while IFS= read -r -d '' slice_framework; do
            local framework_name
            framework_name="$(basename "$slice_framework" .framework)"
            local headers_dir="$slice_framework/Headers"
            local umbrella_path="$headers_dir/$framework_name.h"

            if [[ ! -d "$headers_dir" ]]; then
                continue
            fi

            if [[ -f "$umbrella_path" ]]; then
                umbrella_found=1
                vr_log_info "[XCF] Found umbrella header in $slice ($framework_name)"
                echo "[TRACE][XCF]      Found umbrella: $umbrella_path"

                # Check if umbrella header references exist (with protection against infinite loops)
                if command -v grep >/dev/null 2>&1; then
                    echo "[TRACE][XCF]      Scanning umbrella header references..."
                    local referenced_headers
                    if ! referenced_headers="$(vr_run_with_timeout 10 grep -E '^#import|<.*\.h>' "$umbrella_path" 2>/dev/null | sed -E 's/.*["<]([^">]+)\.h[">].*/\1.h/' || echo "")"; then
                        vr_log_warn "[XCF] grep command timed out on umbrella header"
                        echo "[TRACE][XCF]      grep TIMEOUT on umbrella header"
                    else
                        if [[ -n "$referenced_headers" ]]; then
                            local iteration_count=0
                            while IFS= read -r header && [[ $iteration_count -lt 1000 ]]; do
                                iteration_count=$((iteration_count + 1))
                                # Skip framework-style/system imports (e.g. Foundation/Foundation.h).
                                if [[ "$header" == */* ]]; then
                                    continue
                                fi
                                local header_path="$headers_dir/$header"
                                if [[ ! -f "$header_path" ]]; then
                                    vr_log_warn "[XCF] Umbrella header references missing file: $header"
                                fi
                            done <<< "$referenced_headers"
                            echo "[TRACE][XCF]      Processed $iteration_count header references"
                        fi
                    fi
                fi
                break 2
            fi
        done < <(find "$slice_path" -maxdepth 1 -type d -name "*.framework" -print0 2>/dev/null)
    done
    
    if [[ $umbrella_found -eq 0 ]]; then
        vr_log::error "VERIFY" "[XCF] Missing umbrella header (Headers/$module_name.h)"
        errors=$((errors + 1))
    fi

    if [[ $scanned_frameworks -eq 0 ]]; then
        vr_log_error "[XCF] No framework slices found under XCFramework"
        echo "[TRACE][XCF] <--- Plist scan FAILED (no framework slices)"
        return 1
    fi

    if [[ $errors -gt 0 ]]; then
        vr_log::error "VERIFY" "[XCF] Found $errors critical errors in plist/umbrella validation"
        echo "[TRACE][XCF] <--- Plist scan FAILED ($errors errors)"
        return 1
    fi

    vr_log::info "VERIFY" "[XCF] Info.plist and umbrella header validation passed"
    echo "[TRACE][XCF] <--- Plist scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_plist "$@"
fi
