#!/usr/bin/env bash
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

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_dependencies() {
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
    
    vr_log::info "VERIFY" "[XCF] Scanning dependencies for $module_name..."
    echo "[TRACE][XCF] ---> Entering dependency scan for $module_name"

    if ! command -v otool >/dev/null 2>&1; then
        vr_log::warn "VERIFY" "[XCF] otool not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (otool not found)"
        return 0
    fi

    local -a binaries=()
    while IFS= read -r -d '' framework_dir; do
        local framework_name
        framework_name="$(basename "$framework_dir" .framework)"
        local binary_path="$framework_dir/$framework_name"
        if [[ -f "$binary_path" ]]; then
            binaries+=("$binary_path")
        fi
    done < <(find "$xcframework_path" -type d -name "*.framework" -print0 2>/dev/null)

    if [[ -z "$binary_path" ]] || [[ ! -f "$binary_path" ]]; then
        vr_log::warn "VERIFY" "[XCF] Binary not found, skipping dependency scan"
        echo "[TRACE][XCF] <--- Dependency scan skipped (binary not found)"
        return 0
    fi

    echo "[TRACE][XCF]      Running otool -L on binary: $binary_path"
    local linked_libs
    if ! linked_libs="$(timeout 20s otool -L "$binary_path" 2>/dev/null || echo "")"; then
        vr_log::error "VERIFY" "[XCF] otool command timed out or failed for $module_name"
        echo "[TRACE][XCF] <--- Dependency scan TIMEOUT on otool"
        return 1
    fi
    echo "[TRACE][XCF]      otool completed successfully"
    
    if [[ -z "$linked_libs" ]]; then
        vr_log::warn "VERIFY" "[XCF] Could not read linked libraries"
        return 0
    fi
    
    local forbidden_patterns=(
        "/System/Library/PrivateFrameworks"
        "@rpath/.*Private.*\\.framework"
        "/PrivateFrameworks/"
    )
    
    local violations=0
    while IFS= read -r line; do
        for pattern in "${forbidden_patterns[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                vr_log::error "VERIFY" "[XCF] Forbidden dependency detected: $line"
                violations=$((violations + 1))
            fi
        done
    done <<< "$linked_libs"
    
    if [[ $violations -gt 0 ]]; then
        vr_log::error "VERIFY" "[XCF] Found $violations forbidden dependency violations"
        echo "[TRACE][XCF] <--- Dependency scan FAILED ($violations violations)"
        return 1
    fi

    vr_log::info "VERIFY" "[XCF] Dependency scan passed (no forbidden dependencies)"
    echo "[TRACE][XCF] <--- Dependency scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_dependencies "$@"
fi
