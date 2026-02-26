#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Scan XCFramework Size
# ============================================================================
# Purpose: Validate binary size and generate size report
#
# Usage:   ./scan_size.sh <xcframework_path> <module_name> <report_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

scan_size() {
    local xcframework_path="$1"
    local module_name="$2"
    local report_path="${3:-}"
    
    if [[ -z "$xcframework_path" ]] || [[ ! -d "$xcframework_path" ]]; then
        vr_log::error "VERIFY" "[XCF] Invalid XCFramework path: $xcframework_path"
        return 1
    fi
    
    if [[ -z "$module_name" ]]; then
        vr_log::error "VERIFY" "[XCF] Module name required"
        return 1
    fi
    
    vr_log::info "VERIFY" "[XCF] Scanning size for $module_name..."
    
    local total_size_kb
    total_size_kb="$(du -sk "$xcframework_path" 2>/dev/null | awk '{print $1}' || echo "0")"
    
    local binary_size_kb=0
    local binary_path=""
    local slices=("ios-arm64" "ios-arm64_x86_64-simulator" "ios-arm64-simulator" "ios-x86_64-simulator")
    
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ -d "$slice_path" ]]; then
            binary_path="$(find "$slice_path" -name "$module_name" -type f | head -1)"
            if [[ -n "$binary_path" ]] && [[ -f "$binary_path" ]]; then
                binary_size_kb="$(du -sk "$binary_path" 2>/dev/null | awk '{print $1}' || echo "0")"
                break
            fi
        fi
    done
    
    local swiftinterface_size_kb=0
    for slice in "${slices[@]}"; do
        local slice_path="$xcframework_path/$slice"
        if [[ -d "$slice_path" ]]; then
            local swiftmodule_dir="$slice_path/$module_name.swiftmodule"
            if [[ -d "$swiftmodule_dir" ]]; then
                local interface_size
                interface_size="$(du -sk "$swiftmodule_dir" 2>/dev/null | awk '{print $1}' || echo "0")"
                swiftinterface_size_kb=$((swiftinterface_size_kb + interface_size))
            fi
        fi
    done
    
    if [[ -n "$report_path" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 <<EOF
import json
import sys

report = {
    "binary_size_kb": $binary_size_kb,
    "swiftinterface_size_kb": $swiftinterface_size_kb,
    "total_bundle_kb": $total_size_kb
}

with open("$report_path", "w") as f:
    json.dump(report, f, indent=2)
EOF
            vr_log::info "VERIFY" "[XCF] Size report generated: $report_path"
        else
            # Fallback: simple JSON without python
            cat > "$report_path" <<EOF
{
  "binary_size_kb": $binary_size_kb,
  "swiftinterface_size_kb": $swiftinterface_size_kb,
  "total_bundle_kb": $total_size_kb
}
EOF
            vr_log::info "VERIFY" "[XCF] Size report generated (fallback): $report_path"
        fi
    fi
    
    # Compare with previous version (if state file exists)
    local state_file="${ROOT_DIR:-.}/.msp-release-state.json"
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
        local prev_size
        prev_size="$(jq -r ".xcframework_verify.modules.\"$module_name\".size_kb // empty" "$state_file" 2>/dev/null || echo "")"
        
        if [[ -n "$prev_size" ]] && [[ "$prev_size" != "null" ]] && [[ "$prev_size" != "0" ]]; then
            local size_increase_pct
            size_increase_pct=$(( (total_size_kb * 100) / prev_size - 100 ))
            
            if [[ $size_increase_pct -gt 30 ]]; then
                vr_log::warn "VERIFY" "[XCF] Size increased by +${size_increase_pct}% (threshold: +30%)"
                echo "1"  # Return warning count
                return 0
            fi
        fi
    fi
    
    vr_log::info "VERIFY" "[XCF] Size scan completed: binary=${binary_size_kb}KB, total=${total_size_kb}KB"
    
    echo "0"  # Return warning count
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    scan_size "$@"
fi

