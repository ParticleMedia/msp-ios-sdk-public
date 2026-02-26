#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Remote Verification Runner
# ============================================================================
# Purpose: Unified entry point for running all remote verification checks
#          (SPM and CocoaPods)
#
# Usage:   ./run_all.sh
#          (reads MSP_VERIFY_SPM_URL, MSP_VERIFY_PODS_URL from environment)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/common/utils.sh"

# ============================================================================
# Environment Variable Defaults
# ============================================================================

# Default: enable all verification if not explicitly disabled
REMOTE_VERIFY_ENABLED="${MSP_REMOTE_VERIFY_ENABLED:-1}"
REMOTE_VERIFY_SPM="${MSP_REMOTE_VERIFY_SPM:-1}"
REMOTE_VERIFY_PODS="${MSP_REMOTE_VERIFY_PODS:-1}"

REMOTE_SPM_EXECUTED=0
REMOTE_SPM_SUCCESS=0
REMOTE_PODS_EXECUTED=0
REMOTE_PODS_SUCCESS=0

# ============================================================================
# SPM Remote Verification
# ============================================================================

run_spm_verification() {
    if [[ "$REMOTE_VERIFY_ENABLED" != "1" ]] || [[ "$REMOTE_VERIFY_SPM" != "1" ]]; then
        vr_log::info "REMOTE" "[VR] SPM remote verification skipped (disabled)"
        return 0
    fi
    
    if [[ -z "${MSP_VERIFY_SPM_URL:-}" ]] || [[ -z "${MSP_VERIFY_SPM_VERSION:-}" ]]; then
        vr_log::warn "REMOTE" "[VR] SPM remote verification skipped (missing MSP_VERIFY_SPM_URL / MSP_VERIFY_SPM_VERSION)"
        return 0
    fi
    
    vr_log::info "REMOTE" "[VR] Running SPM remote verification..."
    REMOTE_SPM_EXECUTED=1
    
    if "$SCRIPT_DIR/spm/verify_spm_release.sh" 2>&1; then
        REMOTE_SPM_SUCCESS=1
        vr_log::info "REMOTE" "[VR] SPM remote verification succeeded"
        return 0
    else
        REMOTE_SPM_SUCCESS=0
        vr_log::error "REMOTE" "[VR] SPM remote verification failed"
        return 0  # Soft-fail: return 0 to not break release
    fi
}

# ============================================================================
# CocoaPods Remote Verification
# ============================================================================

run_pods_verification() {
    if [[ "$REMOTE_VERIFY_ENABLED" != "1" ]] || [[ "$REMOTE_VERIFY_PODS" != "1" ]]; then
        vr_log::info "REMOTE" "[VR] Pods remote verification skipped (disabled)"
        return 0
    fi
    
    if [[ -z "${MSP_VERIFY_PODS_URL:-}" ]] || [[ -z "${MSP_VERIFY_PODS_VERSION:-}" ]]; then
        vr_log::warn "REMOTE" "[VR] Pods remote verification skipped (missing MSP_VERIFY_PODS_URL / MSP_VERIFY_PODS_VERSION)"
        return 0
    fi
    
    vr_log::info "REMOTE" "[VR] Running Pods remote verification..."
    REMOTE_PODS_EXECUTED=1
    
    if "$SCRIPT_DIR/cocoapods/verify_pods_release.sh" 2>&1; then
        REMOTE_PODS_SUCCESS=1
        vr_log::info "REMOTE" "[VR] Pods remote verification succeeded"
        return 0
    else
        REMOTE_PODS_SUCCESS=0
        vr_log::error "REMOTE" "[VR] Pods remote verification failed"
        return 0  # Soft-fail: return 0 to not break release
    fi
}

# ============================================================================
# Main Runner
# ============================================================================

run_all_remote_verification() {
    run_spm_verification || true
    run_pods_verification || true

    export REMOTE_SPM_EXECUTED
    export REMOTE_SPM_SUCCESS
    export REMOTE_PODS_EXECUTED
    export REMOTE_PODS_SUCCESS
    
    return 0
}

# ============================================================================
# Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_remote_verification "$@"
fi

