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
# Inject SDK CocoaPods Dependencies
# ============================================================================
# Purpose: Generate Podfile with released SDK modules (config-driven)
#
# Usage:   ./inject_sdk_pods.sh <sandbox_path>
#
# Configuration priority (highest to lowest):
#   1. Environment variables: MSP_VERIFY_LOCAL_VERSION, MSP_VERIFY_LOCAL_MODULES
#   2. State file: .msp-release-state.json (created by release pipeline)
#   3. Defaults: MSPCore only
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

inject_sdk_pods() {
    local sandbox="$1"

    if [[ -z "$sandbox" ]]; then
        vr_log::error "LOCAL" "Sandbox path required"
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template="$script_dir/Podfile.local-verify-template"

    if [[ ! -f "$template" ]]; then
        vr_log::error "LOCAL" "Podfile template not found: $template"
        return 1
    fi

    local demoapp_dir="$sandbox/DemoApp"
    local podfile_path="$demoapp_dir/Podfile"

    # --- Resolve version ---
    local version="${MSP_VERIFY_LOCAL_VERSION:-}"

    if [[ -z "$version" ]]; then
        # Fallback: read from release state file
        vr_detect_root_dir 2>/dev/null || true
        local state_file="${ROOT_DIR:-.}/.msp-release-state.json"
        if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
            version="$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")"
        fi
    fi

    if [[ -z "$version" ]]; then
        vr_log::warn "LOCAL" "[LOCAL] No version found (set MSP_VERIFY_LOCAL_VERSION or create state file)"
        return 0
    fi

    # --- Resolve modules ---
    local modules_str="${MSP_VERIFY_LOCAL_MODULES:-MSPCore}"
    # Convert space-separated string to array
    local pods_modules=()
    read -ra pods_modules <<< "$modules_str"

    # --- Build pod entries ---
    local pod_entries=""
    local module_list=""
    for module in "${pods_modules[@]}"; do
        pod_entries="${pod_entries}  pod '${module}', '${version}'
"
        module_list="${module_list:+${module_list}, }${module}(${version})"
    done

    # --- Generate Podfile from template ---
    # Process line-by-line because {{POD_ENTRIES}} expands to multiple lines
    # (BSD sed on macOS cannot handle newlines in substitution patterns)
    while IFS= read -r line; do
        if [[ "$line" == *"{{POD_ENTRIES}}"* ]]; then
            printf '%s' "$pod_entries"
        else
            line="${line//\{\{PLATFORM_VERSION\}\}/15.0}"
            printf '%s\n' "$line"
        fi
    done < "$template" > "$podfile_path"

    vr_log::info "LOCAL" "[LOCAL] Injected SDK pods: $module_list"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_sdk_pods "$@"
fi

