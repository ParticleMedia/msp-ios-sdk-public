#!/bin/bash
# --- MSP Worktree Safety Guard (Patch K, shared) ---
# shellcheck source=/dev/null
if command -v git >/dev/null 2>&1; then
  MSP_REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$MSP_REPO_ROOT" ] && [ -f "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh" ]; then
    # shellcheck source=/dev/null
    . "$MSP_REPO_ROOT/Scripts/lib/worktree_guard.sh"
    msp_enforce_main_repo_or_exit
  fi
fi
# --- End MSP Worktree Safety Guard (Patch K, shared) ---
# ============================================================================
# CocoaPods Remote Release Verification Orchestrator
# ============================================================================
# Purpose: Orchestrate complete CocoaPods remote release verification
#
# Usage:   ./verify_pods_release.sh
#          (reads MSP_VERIFY_PODS_URL, MSP_VERIFY_PODS_VERSION from environment)
# ============================================================================

set -euo pipefail

# Source common utilities
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
    # Read configuration from environment
    local remote_url="${MSP_VERIFY_PODS_URL:-}"
    local remote_version="${MSP_VERIFY_PODS_VERSION:-}"
    
    # Check if required environment variables are set
    if [[ -z "$remote_url" ]] || [[ -z "$remote_version" ]]; then
        vr_log_warn "Pods remote verification skipped (missing MSP_VERIFY_PODS_URL / MSP_VERIFY_PODS_VERSION)"
        return 0
    fi
    
    # Create sandbox
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "pods")" || {
        vr_log_error "Failed to create sandbox"
        return 1
    }
    
    # Set up trap to clean up sandbox on exit
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    # Call scripts in order
    vr_log_info "Starting Pods remote verification (URL=$remote_url, version=$remote_version)"
    
    # Step 1: Prepare DemoApp
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to prepare DemoApp"
        return 1
    fi
    
    # Step 2: Patch Podfile
    if ! "$SCRIPT_DIR/patch_podfile.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to patch Podfile"
        return 1
    fi
    
    # Step 3: Run pod install
    if ! "$SCRIPT_DIR/pod_install.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to run pod install"
        return 1
    fi
    
    # Step 4: Build DemoApp
    if ! "$SCRIPT_DIR/build_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to build DemoApp"
        return 1
    fi
    
    # On success, log completion
    vr_log_info "Pods remote verification (URL=$remote_url, version=$remote_version) completed successfully."
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_pods_release "$@"
fi

