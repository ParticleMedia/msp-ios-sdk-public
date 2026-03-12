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
# Scan XCFramework Symbol Table
# ============================================================================
# Purpose: Validate symbol table (no private/debug symbols leaked)
#
# Usage:   ./scan_symbols.sh <xcframework_path> <module_name>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_symbols() {
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
    
    vr_log::info "VERIFY" "[XCF] Scanning symbol table for $module_name..."
    echo "[TRACE][XCF] ---> Entering symbol scan for $module_name"

    if ! command -v nm >/dev/null 2>&1; then
        vr_log::warn "VERIFY" "[XCF] nm not found, skipping symbol scan"
        echo "[TRACE][XCF] <--- Symbol scan skipped (nm not found)"
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
        vr_log::warn "VERIFY" "[XCF] Binary not found, skipping symbol scan"
        echo "[TRACE][XCF] <--- Symbol scan skipped (binary not found)"
        return 0
    fi

    echo "[TRACE][XCF]      Running nm on binary: $binary_path"
    local symbols
    if ! symbols="$(timeout 20s nm -gU "$binary_path" 2>/dev/null || echo "")"; then
        vr_log::error "VERIFY" "[XCF] nm command timed out or failed for $module_name"
        echo "[TRACE][XCF] <--- Symbol scan TIMEOUT on nm"
        return 1
    fi
    echo "[TRACE][XCF]      nm completed successfully"
    
    if [[ -z "$symbols" ]]; then
        vr_log::warn "VERIFY" "[XCF] Could not extract symbols"
        return 0
    fi
    
    local forbidden_patterns=(
        "_OBJC_CLASS_\$_"
        "__Z"
        "__T"
        "\.debug_"
        "__internal_"
    )
    
    local violations=0
    while IFS= read -r line; do
        for pattern in "${forbidden_patterns[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                vr_log::error "VERIFY" "[XCF] Forbidden symbol detected: $line"
                violations=$((violations + 1))
            fi
        done
    done <<< "$symbols"
    
    if [[ $violations -gt 0 ]]; then
        vr_log::error "VERIFY" "[XCF] Found $violations forbidden symbol violations"
        echo "[TRACE][XCF] <--- Symbol scan FAILED ($violations violations)"
        return 1
    fi

    vr_log::info "VERIFY" "[XCF] Symbol scan passed (no forbidden symbols)"
    echo "[TRACE][XCF] <--- Symbol scan completed successfully"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_symbols "$@"
fi
