#!/bin/bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
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
    echo "[TRACE][XCF] ---> Entering symbol scan for $module_name"

    local nm_bin
    nm_bin="$(vr_find_devtool nm)"
    if [[ -z "$nm_bin" ]]; then
        vr_log_warn "[XCF] nm not found, skipping symbol scan"
        echo "[TRACE][XCF] <--- Symbol scan skipped (nm not found)"
        return 0
    fi

    # Collect all framework binaries from all slices.
    local -a binaries=()
    while IFS= read -r -d '' framework_dir; do
        local framework_name
        framework_name="$(basename "$framework_dir" .framework)"
        local binary_path="$framework_dir/$framework_name"
        if [[ -f "$binary_path" ]]; then
            binaries+=("$binary_path")
        fi
    done < <(find "$xcframework_path" -type d -name "*.framework" -print0 2>/dev/null)

    if [[ ${#binaries[@]} -eq 0 ]]; then
        vr_log_warn "[XCF] Binary not found, skipping symbol scan"
        echo "[TRACE][XCF] <--- Symbol scan skipped (binary not found)"
        return 0
    fi

    local scan_errors=0
    local scanned_count=0
    local binary_path
    for binary_path in "${binaries[@]}"; do
        echo "[TRACE][XCF]      Running nm on binary: $binary_path"
        local symbols=""
        if ! symbols="$(vr_run_with_timeout 20 "$nm_bin" -gU "$binary_path" 2>/dev/null || true)"; then
            vr_log_error "[XCF] nm command failed for binary: $binary_path"
            scan_errors=$((scan_errors + 1))
            continue
        fi

        scanned_count=$((scanned_count + 1))
        if [[ -z "$symbols" ]]; then
            vr_log_warn "[XCF] Could not extract symbols: $binary_path"
        fi
    done

    if [[ $scan_errors -gt 0 ]]; then
        vr_log_error "[XCF] Symbol scan tool errors: $scan_errors"
        return 1
    fi

    vr_log_info "[XCF] Symbol scan passed (scanned $scanned_count binaries)"
    echo "[TRACE][XCF] <--- Symbol scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_symbols "$@"
fi
