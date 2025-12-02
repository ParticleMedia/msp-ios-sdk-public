#!/bin/bash
# ============================================================================
# XCFramework Verification Runner
# ============================================================================
# Purpose: Orchestrate XCFramework deep verification
#
# Usage:   ./run_xcf.sh
#          (reads from .msp-release-state.json to find XCFrameworks)
# ============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/../verify_remote/common/utils.sh"
# shellcheck source=Scripts/release/verify_remote/common/sandbox.sh
source "$SCRIPT_DIR/../verify_remote/common/sandbox.sh"

# Source XCFramework scan scripts
source "$SCRIPT_DIR/scan_architectures.sh"
source "$SCRIPT_DIR/scan_swiftmodules.sh"
source "$SCRIPT_DIR/scan_dependencies.sh"
source "$SCRIPT_DIR/scan_plist.sh"
source "$SCRIPT_DIR/scan_symbols.sh"
source "$SCRIPT_DIR/scan_size.sh"

# Ensure ROOT_DIR is detected
vr_detect_root_dir || {
    vr_log_error "Failed to detect ROOT_DIR"
    return 1
}

# ============================================================================
# Environment Variable Defaults
# ============================================================================

# Default: enable verification if not explicitly disabled
XCF_VERIFY_ENABLED="${MSP_XCF_VERIFY_ENABLED:-1}"

# Initialize result variables
XCF_VERIFY_EXECUTED=0
declare -A XCF_VERIFY_MODULE_RESULTS
declare -A XCF_VERIFY_MODULE_WARNINGS

# ============================================================================
# Main Runner
# ============================================================================

run_xcframework_verification() {
    # Check if XCFramework verification is enabled
    if [[ "$XCF_VERIFY_ENABLED" != "1" ]]; then
        vr_log_info "[XCF] XCFramework verification disabled (MSP_XCF_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    vr_log_info "[XCF] Starting XCFramework deep verification..."
    XCF_VERIFY_EXECUTED=1
    
    # Find XCFrameworks in build output
    local xcframeworks_dir="${XCFRAMEWORKS_DIR:-$ROOT_DIR/build/xcframeworks}"
    if [[ ! -d "$xcframeworks_dir" ]]; then
        vr_log_warn "[XCF] XCFrameworks directory not found: $xcframeworks_dir"
        return 0  # Soft-fail
    fi
    
    # Create sandbox
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "xcf")" || {
        vr_log_error "[XCF] Failed to create sandbox"
        return 0  # Soft-fail
    }
    
    # Set up trap to clean up sandbox on exit
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    # Find all XCFrameworks
    local xcframeworks=()
    while IFS= read -r -d '' xcf; do
        xcframeworks+=("$xcf")
    done < <(find "$xcframeworks_dir" -name "*.xcframework" -type d -print0 2>/dev/null)
    
    if [[ ${#xcframeworks[@]} -eq 0 ]]; then
        vr_log_warn "[XCF] No XCFrameworks found in $xcframeworks_dir"
        return 0  # Soft-fail
    fi
    
    vr_log_info "[XCF] Found ${#xcframeworks[@]} XCFramework(s) to verify"
    
    # Process each XCFramework
    for xcf_path in "${xcframeworks[@]}"; do
        local module_name
        module_name="$(basename "$xcf_path" .xcframework)"
        
        vr_log_info "[XCF] Verifying $module_name..."
        
        # Copy XCFramework to sandbox
        local sandbox_xcf="$SANDBOX_DIR/$module_name.xcframework"
        cp -R "$xcf_path" "$sandbox_xcf" || {
            vr_log_error "[XCF] Failed to copy $module_name to sandbox"
            XCF_VERIFY_MODULE_RESULTS["$module_name"]=0
            XCF_VERIFY_MODULE_WARNINGS["$module_name"]=0
            continue
        }
        
        local module_success=1
        local module_warnings=0
        
        # Run all scans
        local scan_warnings
        
        # 1. Architecture scan
        if ! scan_warnings="$(scan_architectures "$sandbox_xcf" "$module_name" 2>&1)"; then
            vr_log_warn "[XCF] Architecture scan failed for $module_name"
        else
            if [[ -n "$scan_warnings" ]] && [[ "$scan_warnings" =~ ^[0-9]+$ ]]; then
                module_warnings=$((module_warnings + scan_warnings))
            fi
        fi
        
        # 2. Swift module scan
        if ! scan_swiftmodules "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Swift module scan failed for $module_name"
            module_success=0
        fi
        
        # 3. Dependency scan
        if ! scan_dependencies "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Dependency scan failed for $module_name"
            module_success=0
        fi
        
        # 4. Plist scan
        if ! scan_plist "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Plist scan failed for $module_name"
            module_success=0
        fi
        
        # 5. Symbol scan
        if ! scan_symbols "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Symbol scan failed for $module_name"
            module_success=0
        fi
        
        # 6. Size scan
        local size_report="$SANDBOX_DIR/${module_name}.size_report.json"
        if ! scan_warnings="$(scan_size "$sandbox_xcf" "$module_name" "$size_report" 2>&1)"; then
            vr_log_warn "[XCF] Size scan failed for $module_name"
        else
            if [[ -n "$scan_warnings" ]] && [[ "$scan_warnings" =~ ^[0-9]+$ ]]; then
                module_warnings=$((module_warnings + scan_warnings))
            fi
        fi
        
        # Record results
        XCF_VERIFY_MODULE_RESULTS["$module_name"]=$module_success
        XCF_VERIFY_MODULE_WARNINGS["$module_name"]=$module_warnings
        
        if [[ $module_success -eq 1 ]]; then
            vr_log_info "[XCF] $module_name: PASS ($module_warnings warnings)"
        else
            vr_log_error "[XCF] $module_name: FAIL ($module_warnings warnings)"
        fi
    done
    
    # Export results for orchestrator
    export XCF_VERIFY_EXECUTED
    
    # Build JSON structure for state file
    local json_modules="{"
    local first=1
    for module in "${!XCF_VERIFY_MODULE_RESULTS[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            json_modules="$json_modules,"
        fi
        local success="${XCF_VERIFY_MODULE_RESULTS[$module]}"
        local warnings="${XCF_VERIFY_MODULE_WARNINGS[$module]:-0}"
        json_modules="$json_modules\"$module\":{\"success\":$success,\"warnings\":$warnings}"
    done
    json_modules="$json_modules}"
    
    export XCF_VERIFY_MODULES_JSON="$json_modules"
    
    return 0
}

# ============================================================================
# Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_xcframework_verification "$@"
fi

