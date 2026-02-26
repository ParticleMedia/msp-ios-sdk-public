#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Execute pod install in Sandbox
# ============================================================================
# Purpose: Run pod install in isolated sandbox directory
#
# Usage:   ./pod_install.sh <sandbox_path>
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

source "$(dirname "$0")/../common/utils.sh"

# R036b: Source cocoapods module for unified pod operations
COCOAPODS_MODULE_AVAILABLE=false
if [[ -f "$ROOT_DIR/Scripts/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$ROOT_DIR/Scripts/lib/cocoapods.sh" 2>/dev/null || true
    if command -v validate_cocoapods_environment &>/dev/null; then
        COCOAPODS_MODULE_AVAILABLE=true
    fi
fi

# ============================================================================
# Functions
# ============================================================================

run_pod_install() {
    local sandbox="$1"

    if [[ -z "$sandbox" ]]; then
        vr_log::error "PODS" "Sandbox path required"
        return 1
    fi

    # R036b: Use cocoapods.sh module for environment validation if available
    if [[ "$COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
        if ! validate_cocoapods_environment 2>/dev/null; then
            vr_log::warn "PODS" "pod command not found, skipping CocoaPods verification"
            return 0
        fi
    else
        # Fallback: Check if pod command exists directly
        if ! command -v pod >/dev/null 2>&1; then
            vr_log::warn "PODS" "pod command not found, skipping CocoaPods verification"
            return 0
        fi
    fi

    local demoapp_dir="$sandbox/DemoApp"
    local podfile="$demoapp_dir/Podfile"

    if [[ ! -f "$podfile" ]]; then
        vr_log::error "PODS" "Podfile not found: $podfile"
        return 1
    fi

    # Create log file in sandbox for pod install output (persisted for debugging)
    local pod_log
    pod_log="$sandbox/pod_install.log"
    mkdir -p "$sandbox" || true

    pushd "$demoapp_dir" >/dev/null || {
        vr_log::error "PODS" "Failed to change to DemoApp directory: $demoapp_dir"
        return 1
    }

    vr_log::info "PODS" "[PODS] Running pod install..."

    # R036b: Use cocoapods.sh module's install_pods if available
    local install_success=false
    if [[ "$COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
        # Temporarily redirect output to log file
        if install_pods 2>&1 | tee "$pod_log"; then
            install_success=true
        fi
    else
        # Fallback: Direct pod install
        if pod install --project-directory=. >"$pod_log" 2>&1; then
            install_success=true
        fi
    fi

    if [[ "$install_success" == "true" ]]; then
        vr_log::info "PODS" "[PODS] pod install succeeded"

        # Verify expected outputs
        if [[ -d "$demoapp_dir/MSPDemoApp.xcworkspace" ]] && [[ -d "$demoapp_dir/Pods" ]]; then
            vr_log::info "PODS" "[PODS] Workspace and Pods directory created successfully"
        else
            vr_log::warn "PODS" "[PODS] Workspace or Pods directory missing after pod install"
        fi

        vr_log::info "PODS" "[PODS] Pod install log saved to: $pod_log"

        popd >/dev/null
        return 0
    else
        vr_log::error "PODS" "[PODS] pod install failed (see diagnostics below)"
        echo "------ Full pod install log at: $pod_log ------"
        cat "$pod_log"
        echo "------------------------------------------------"
        popd >/dev/null
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_pod_install "$@"
fi
