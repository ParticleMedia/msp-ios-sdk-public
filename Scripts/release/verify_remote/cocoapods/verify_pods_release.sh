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
# CocoaPods Remote Release Verification Orchestrator
# ============================================================================
# Purpose: Orchestrate complete CocoaPods remote release verification
#
# Usage:   ./verify_pods_release.sh
#          (reads MSP_VERIFY_PODS_URL, MSP_VERIFY_PODS_VERSION from environment)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/../common/utils.sh"
# shellcheck source=Scripts/release/verify_remote/common/sandbox.sh
source "$SCRIPT_DIR/../common/sandbox.sh"

# Source CocoaPods verification scripts
source "$SCRIPT_DIR/prepare_demoapp.sh"
source "$SCRIPT_DIR/patch_podfile.sh"
source "$SCRIPT_DIR/pod_install.sh"
source "$SCRIPT_DIR/build_demoapp.sh"

# ============================================================================
# Main Verification Flow
# ============================================================================

verify_pods_release() {
    local remote_url="${MSP_VERIFY_PODS_URL:-}"
    local remote_version="${MSP_VERIFY_PODS_VERSION:-}"
    
    if [[ -z "$remote_url" ]] || [[ -z "$remote_version" ]]; then
        vr_log::warn "PODS" "Pods remote verification skipped (missing MSP_VERIFY_PODS_URL / MSP_VERIFY_PODS_VERSION)"
        return 0
    fi
    
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "pods")" || {
        vr_log::error "PODS" "Failed to create sandbox"
        return 1
    }
    
    # Set up trap to clean up sandbox on exit
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    vr_log::info "PODS" "Starting Pods remote verification (URL=$remote_url, version=$remote_version)"
    
    # Step 1: Prepare DemoApp
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log::error "PODS" "Failed to prepare DemoApp"
        return 1
    fi
    
    # Step 2: Patch Podfile
    if ! "$SCRIPT_DIR/patch_podfile.sh" "$SANDBOX_DIR"; then
        vr_log::error "PODS" "Failed to patch Podfile"
        return 1
    fi
    
    # Step 3: Run pod install
    if ! "$SCRIPT_DIR/pod_install.sh" "$SANDBOX_DIR"; then
        vr_log::error "PODS" "Failed to run pod install"
        return 1
    fi
    
    # Step 4: Build DemoApp
    if ! "$SCRIPT_DIR/build_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log::error "PODS" "Failed to build DemoApp"
        return 1
    fi
    
    vr_log::info "PODS" "Pods remote verification (URL=$remote_url, version=$remote_version) completed successfully."
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_pods_release "$@"
fi

