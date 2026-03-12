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
# Scan XCFramework Swift Modules
# ============================================================================
# Purpose: Validate Swift module files exist
#
# Usage:   ./scan_swiftmodules.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_swiftmodules() {
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
    
    vr_log::info "VERIFY" "[XCF] Scanning Swift modules for $module_name..."
    
    local missing_files=0
    local scanned_module_dirs=0
    
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")
    
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ ! -d "$slice_path" ]]; then
            continue
        fi
        
        local found_swiftmodule_dir=0
        while IFS= read -r -d '' module_dir; do
            found_swiftmodule_dir=1
            scanned_module_dirs=$((scanned_module_dirs + 1))

            local iface_count
            iface_count="$(find "$module_dir" -maxdepth 1 -name "*.swiftinterface" -type f | wc -l | tr -d ' ')"
            if [[ "$iface_count" == "0" ]]; then
                vr_log_error "[XCF] Missing .swiftinterface in $slice: $module_dir"
                missing_files=$((missing_files + 1))
            else
                vr_log_info "[XCF] Found $iface_count .swiftinterface file(s) in $slice"
            fi
        done < <(find "$slice_path" -type d -name "*.swiftmodule" -print0 2>/dev/null)

        local swiftmodule_path="$slice_path/$module_name.swiftmodule/$(uname -m).swiftmodule"
        if [[ ! -f "$swiftmodule_path" ]]; then
            swiftmodule_path="$slice_path/$module_name.swiftmodule/arm64-apple-ios.swiftmodule"
            if [[ ! -f "$swiftmodule_path" ]]; then
                swiftmodule_path="$slice_path/$module_name.swiftmodule/x86_64-apple-ios-simulator.swiftmodule"
            fi
        fi
        
        if [[ ! -f "$swiftmodule_path" ]]; then
            vr_log::warn "VERIFY" "[XCF] Missing .swiftmodule in $slice (may be acceptable for interface-only modules)"
        else
            vr_log::info "VERIFY" "[XCF] Found .swiftmodule in $slice"
        fi
    done
    
    if [[ $missing_files -gt 0 ]]; then
        vr_log::error "VERIFY" "[XCF] Missing critical Swift module files (SPM/Pods cannot work)"
        return 1
    fi

    vr_log_info "[XCF] Swift module scan passed (checked $scanned_module_dirs module dir(s))"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_swiftmodules "$@"
fi
