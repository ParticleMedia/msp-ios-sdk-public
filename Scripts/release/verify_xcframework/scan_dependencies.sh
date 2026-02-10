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

    local otool_bin
    otool_bin="$(vr_find_devtool otool)"
    if [[ -z "$otool_bin" ]]; then
        vr_log_warn "[XCF] otool not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (otool not found)"
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
        vr_log_warn "[XCF] Binary not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (binary not found)"
        return 0
    fi

    # Check for forbidden patterns.
    local forbidden_patterns=(
        "/System/Library/PrivateFrameworks"
        "@rpath/.*Private.*\\.framework"
        "/PrivateFrameworks/"
    )
    
    local violations=0
    local scan_errors=0
    local binary_path
    for binary_path in "${binaries[@]}"; do
        echo "[TRACE][XCF]      Running otool -L on binary: $binary_path"
        local linked_libs=""
        if ! linked_libs="$(vr_run_with_timeout 20 "$otool_bin" -L "$binary_path" 2>/dev/null || true)"; then
            vr_log_error "[XCF] otool command failed for binary: $binary_path"
            scan_errors=$((scan_errors + 1))
            continue
        fi

        if [[ -z "$linked_libs" ]]; then
            vr_log_warn "[XCF] Could not read linked libraries: $binary_path"
            continue
        fi

        while IFS= read -r line; do
            for pattern in "${forbidden_patterns[@]}"; do
                if echo "$line" | grep -qE "$pattern"; then
                    vr_log_error "[XCF] Forbidden dependency detected: $line"
                    violations=$((violations + 1))
                fi
            done
        done <<< "$linked_libs"
    done

    if [[ $scan_errors -gt 0 ]]; then
        vr_log_error "[XCF] Dependency scan tool errors: $scan_errors"
        return 1
    fi

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
