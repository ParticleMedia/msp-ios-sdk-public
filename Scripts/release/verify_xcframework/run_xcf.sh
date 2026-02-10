#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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
# Use regular arrays instead of associative arrays for Bash 3.2 compatibility
XCF_VERIFY_MODULE_NAMES=()
XCF_VERIFY_MODULE_RESULTS=()
XCF_VERIFY_MODULE_WARNINGS=()
XCF_VERIFY_MODULE_FAILED_SCANS=()

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

    # Find XCFrameworks in build output
    # Multi-path fallback (same as worktree)
    local xcframeworks_dir="${XCFRAMEWORKS_DIR:-}"
    if [[ -z "$xcframeworks_dir" ]]; then
        if [[ -d "$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks" ]]; then
            xcframeworks_dir="$ROOT_DIR/Build/ReleaseArtifacts/XCFrameworks"
        elif [[ -d "$ROOT_DIR/build/xcframeworks" ]]; then
            xcframeworks_dir="$ROOT_DIR/build/xcframeworks"
        else
            vr_log_error "[XCF] XCFramework directory not found under root: $ROOT_DIR"
            return 0  # Soft-fail
        fi
    fi
    
    echo "[XCF][INFO] Using XCFrameworks directory: $xcframeworks_dir"
    
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


        # Skip Mintegral modules — handled via remote CocoaPods dependency
        if [[ "$module_name" == "MintegralAdapter" ]] || [[ "$module_name" == "MintegralAdSDK" ]]; then
            vr_log_info "[XCF] Skipping Mintegral module ($module_name) — handled via remote CocoaPods dependency"
            continue
        fi
        vr_log_info "[XCF] Verifying $module_name..."
        echo "======================================================================"
        echo "[TRACE][XCF] ====> STARTING VERIFICATION FOR: $module_name"
        echo "======================================================================"

        # Copy XCFramework to sandbox
        echo "[TRACE][XCF]      Copying to sandbox..."
        local sandbox_xcf="$SANDBOX_DIR/${module_name}.xcframework"
        if ! vr_run_with_timeout 30 cp -R "$xcf_path" "$sandbox_xcf" 2>/dev/null; then
            vr_log_error "[XCF] Failed to copy $module_name to sandbox (timeout or error)"
            echo "[TRACE][XCF]      Copy FAILED or TIMEOUT"
            XCF_VERIFY_MODULE_NAMES+=("$module_name")
            XCF_VERIFY_MODULE_RESULTS+=(0)
            XCF_VERIFY_MODULE_WARNINGS+=(0)
            continue
        fi
        echo "[TRACE][XCF]      Copy completed successfully"

        local module_success=1
        local module_warnings=0
        local failed_scans=""

        # Run all scans
        local scan_warnings

        # 1. Architecture scan
        echo "[TRACE][XCF]      Starting architecture scan..."
        if ! scan_warnings="$(scan_architectures "$sandbox_xcf" "$module_name" 2>&1)"; then
            vr_log_warn "[XCF] Architecture scan failed for $module_name"
        else
            if [[ -n "$scan_warnings" ]] && [[ "$scan_warnings" =~ ^[0-9]+$ ]]; then
                module_warnings=$((module_warnings + scan_warnings))
            fi
        fi

        # 2. Swift module scan
        echo "[TRACE][XCF]      Starting Swift module scan..."
        if ! vr_run_with_timeout 60 scan_swiftmodules "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Swift module scan failed for $module_name"
            echo "[TRACE][XCF]      Swift module scan FAILED or TIMEOUT"
            module_success=0
            failed_scans="${failed_scans}swiftmodules,"
        fi

        # 3. Dependency scan
        echo "[TRACE][XCF]      Starting dependency scan..."
        if ! vr_run_with_timeout 60 scan_dependencies "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Dependency scan failed for $module_name"
            echo "[TRACE][XCF]      Dependency scan FAILED or TIMEOUT"
            module_success=0
            failed_scans="${failed_scans}dependencies,"
        fi

        # 4. Plist scan
        echo "[TRACE][XCF]      Starting plist scan..."
        if ! vr_run_with_timeout 60 scan_plist "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Plist scan failed for $module_name"
            echo "[TRACE][XCF]      Plist scan FAILED or TIMEOUT"
            module_success=0
            failed_scans="${failed_scans}plist,"
        fi

        # 5. Symbol scan
        echo "[TRACE][XCF]      Starting symbol scan..."
        if ! vr_run_with_timeout 60 scan_symbols "$sandbox_xcf" "$module_name" >/dev/null 2>&1; then
            vr_log_error "[XCF] Symbol scan failed for $module_name"
            echo "[TRACE][XCF]      Symbol scan FAILED or TIMEOUT"
            module_success=0
            failed_scans="${failed_scans}symbols,"
        fi

        # 6. Size scan
        echo "[TRACE][XCF]      Starting size scan..."
        local size_report="$SANDBOX_DIR/${module_name}.size_report.json"
        if ! scan_warnings="$(vr_run_with_timeout 30 scan_size "$sandbox_xcf" "$module_name" "$size_report" 2>&1)"; then
            vr_log_warn "[XCF] Size scan failed for $module_name"
            echo "[TRACE][XCF]      Size scan FAILED or TIMEOUT"
        else
            if [[ -n "$scan_warnings" ]] && [[ "$scan_warnings" =~ ^[0-9]+$ ]]; then
                module_warnings=$((module_warnings + scan_warnings))
            fi
        fi

        # Remove trailing comma from failed_scans
        failed_scans="${failed_scans%,}"

        # Record results
        XCF_VERIFY_MODULE_NAMES+=("$module_name")
        XCF_VERIFY_MODULE_RESULTS+=($module_success)
        XCF_VERIFY_MODULE_WARNINGS+=($module_warnings)
        XCF_VERIFY_MODULE_FAILED_SCANS+=("$failed_scans")

        if [[ $module_success -eq 1 ]]; then
            vr_log_info "[XCF] $module_name: PASS ($module_warnings warnings)"
            echo "[TRACE][XCF] <==== COMPLETED $module_name: PASS ($module_warnings warnings)"
        else
            vr_log_error "[XCF] $module_name: FAIL ($module_warnings warnings)"
            echo "[TRACE][XCF] <==== COMPLETED $module_name: FAIL ($module_warnings warnings)"
        fi
        echo "======================================================================"
        echo ""
    done

    # Build JSON structure for state file
    local json_modules="{"
    local first=1
    local idx=0
    for module_name in "${XCF_VERIFY_MODULE_NAMES[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            json_modules="$json_modules,"
        fi
        local success="${XCF_VERIFY_MODULE_RESULTS[$idx]}"
        local warnings="${XCF_VERIFY_MODULE_WARNINGS[$idx]:-0}"
        local failed_scan_list="${XCF_VERIFY_MODULE_FAILED_SCANS[$idx]:-}"

        # Convert comma-separated failed scans to JSON array
        local failed_scans_json="[]"
        if [[ -n "$failed_scan_list" ]]; then
            failed_scans_json="["
            local scan_first=1
            IFS=',' read -ra SCANS <<< "$failed_scan_list"
            for scan in "${SCANS[@]}"; do
                if [[ $scan_first -eq 1 ]]; then
                    scan_first=0
                else
                    failed_scans_json="$failed_scans_json,"
                fi
                failed_scans_json="$failed_scans_json\"$scan\""
            done
            failed_scans_json="$failed_scans_json]"
        fi

        json_modules="$json_modules\"$module_name\":{\"success\":$success,\"warnings\":$warnings,\"failed_scans\":$failed_scans_json}"
        idx=$((idx + 1))
    done
    json_modules="$json_modules}"

    export XCF_VERIFY_MODULES_JSON="$json_modules"

    # Return non-zero when any module fails, so orchestrator can block release.
    local total_modules=${#XCF_VERIFY_MODULE_NAMES[@]}
    local failed_modules=0
    local module_result
    for module_result in "${XCF_VERIFY_MODULE_RESULTS[@]}"; do
        if [[ "$module_result" != "1" ]]; then
            failed_modules=$((failed_modules + 1))
        fi
    done

    export XCF_VERIFY_TOTAL_MODULES="$total_modules"
    export XCF_VERIFY_FAILED_MODULES="$failed_modules"

    if [[ "$failed_modules" -gt 0 ]]; then
        vr_log_error "[XCF] Verification failed: ${failed_modules}/${total_modules} module(s) failed"
        return 1
    fi

    vr_log_info "[XCF] Verification passed: ${total_modules}/${total_modules} module(s) passed"
    return 0
}

# ============================================================================
# Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_xcframework_verification "$@"
fi
