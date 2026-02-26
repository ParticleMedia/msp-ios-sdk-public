#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Patch Podfile for Remote CocoaPods Verification
# ============================================================================
# Purpose: Generate Podfile for trunk-based verification (consumer perspective)
#
# Usage:   ./patch_podfile.sh <sandbox_path>
#          (reads MSP_VERIFY_PODS_VERSION from environment)
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

patch_podfile() {
    local sandbox="$1"

    if [[ -z "$sandbox" ]]; then
        vr_log::error "PODS" "Sandbox path required"
        return 1
    fi

    # Read configuration from environment
    local pod_name="${MSP_VERIFY_PODS_NAME:-MSPCore}"
    local remote_version="${MSP_VERIFY_PODS_VERSION:-}"

    if [[ -z "$remote_version" ]]; then
        vr_log::error "PODS" "MSP_VERIFY_PODS_VERSION required"
        return 1
    fi

    # Read Podfile template (config-driven)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template="$script_dir/Podfile.verify-template"

    if [[ ! -f "$template" ]]; then
        vr_log::error "PODS" "Podfile template not found: $template"
        return 1
    fi

    local podfile_path="$sandbox/DemoApp/Podfile"
    sed -e "s|{{POD_NAME}}|$pod_name|g" \
        -e "s|{{POD_VERSION}}|$remote_version|g" \
        "$template" > "$podfile_path"

    vr_log::info "PODS" "[PODS] Patched Podfile (pod=$pod_name, version=$remote_version)"

    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    patch_podfile "$@"
fi
