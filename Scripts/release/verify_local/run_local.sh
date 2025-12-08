#!/bin/bash
# ============================================================================
# Local Verification Runner
# ============================================================================
# Purpose: Orchestrate local verification of released SDK
#
# Usage:   ./run_local.sh
#          (reads MSP_LOCAL_VERIFY_ENABLED, MSP_LOCAL_USE_PODS, MSP_LOCAL_USE_SPM from environment)
# ============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/../verify_remote/common/utils.sh"
# shellcheck source=Scripts/release/verify_remote/common/sandbox.sh
source "$SCRIPT_DIR/../verify_remote/common/sandbox.sh"

# Source local verification scripts
source "$SCRIPT_DIR/prepare_demoapp.sh"
source "$SCRIPT_DIR/inject_sdk_pods.sh"
source "$SCRIPT_DIR/inject_sdk_spm.sh"
source "$SCRIPT_DIR/build_demoapp.sh"

# ============================================================================
# Environment Variable Defaults
# ============================================================================

# Default: enable all verification if not explicitly disabled
LOCAL_VERIFY_ENABLED="${MSP_LOCAL_VERIFY_ENABLED:-1}"
LOCAL_USE_PODS="${MSP_LOCAL_USE_PODS:-1}"
LOCAL_USE_SPM="${MSP_LOCAL_USE_SPM:-1}"

# Initialize result variables
LOCAL_VERIFY_EXECUTED=0
LOCAL_VERIFY_SUCCESS=0
LOCAL_VERIFY_MODE=""

# ============================================================================
# Main Runner
# ============================================================================

run_local_verification() {
    # Check if local verification is enabled
    if [[ "$LOCAL_VERIFY_ENABLED" != "1" ]]; then
        vr_log_info "[LOCAL] Local verification disabled (MSP_LOCAL_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    # Determine which mode to use (prefer Pods if both enabled)
    local mode=""
    if [[ "$LOCAL_USE_PODS" == "1" ]]; then
        mode="pods"
    elif [[ "$LOCAL_USE_SPM" == "1" ]]; then
        mode="spm"
    else
        vr_log_warn "[LOCAL] Both Pods and SPM are disabled, skipping local verification"
        return 0
    fi
    
    vr_log_info "[LOCAL] Starting local verification (mode: $mode)..."
    LOCAL_VERIFY_EXECUTED=1
    LOCAL_VERIFY_MODE="$mode"
    
    # Create sandbox
    vr_log_info "[DEBUG] Entering sandbox creation"
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "local")" || {
        vr_log_error "[LOCAL] Failed to create sandbox"
        return 0  # Soft-fail
    }
    vr_log_info "[DEBUG] Sandbox created: $SANDBOX_DIR"
    vr_log_info "[DEBUG] Listing sandbox after creation: $(ls -la "$SANDBOX_DIR" 2>/dev/null | head -10 || echo '(empty or error)')"
    
    # Set up trap to clean up sandbox on exit (unless MSP_KEEP_SANDBOX is set)
    local cleanup_sandbox_path="$SANDBOX_DIR"
    if [[ "${MSP_KEEP_SANDBOX:-0}" == "1" ]]; then
        vr_log_info "[PATCH H] Sandbox retention enabled — sandbox will be preserved: $SANDBOX_DIR"
    else
        trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    fi
    
    # Step 1: Prepare DemoApp
    vr_log_info "[DEBUG] Entering prepare_demoapp"
    vr_log_info "[DEBUG] Listing sandbox before prepare_demoapp: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -20 || echo '(empty)')"
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "[LOCAL] Failed to prepare DemoApp"
        vr_log_info "[DEBUG] Listing sandbox after prepare_demoapp FAILED: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -20 || echo '(empty)')"
        return 0  # Soft-fail
    fi
    vr_log_info "[DEBUG] Exiting prepare_demoapp (success)"
    vr_log_info "[DEBUG] Listing sandbox after prepare_demoapp: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -30 || echo '(empty)')"
    
    # Step 2: Inject SDK dependencies
    vr_log_info "[DEBUG] Entering inject_sdk_${mode}"
    if [[ "$mode" == "pods" ]]; then
        vr_log_info "[DEBUG] Listing sandbox before inject_sdk_pods: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -30 || echo '(empty)')"
        if ! "$SCRIPT_DIR/inject_sdk_pods.sh" "$SANDBOX_DIR"; then
            vr_log_error "[LOCAL] Failed to inject Pods dependencies"
            vr_log_info "[DEBUG] Listing sandbox after inject_sdk_pods FAILED: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -30 || echo '(empty)')"
            return 0  # Soft-fail
        fi
        vr_log_info "[DEBUG] Exiting inject_sdk_pods (success)"
        vr_log_info "[DEBUG] Listing sandbox after inject_sdk_pods: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -40 || echo '(empty)')"
    else
        vr_log_info "[DEBUG] Listing sandbox before inject_sdk_spm: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -30 || echo '(empty)')"
        if ! "$SCRIPT_DIR/inject_sdk_spm.sh" "$SANDBOX_DIR"; then
            vr_log_error "[LOCAL] Failed to inject SPM dependencies"
            vr_log_info "[DEBUG] Listing sandbox after inject_sdk_spm FAILED: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -30 || echo '(empty)')"
            return 0  # Soft-fail
        fi
        vr_log_info "[DEBUG] Exiting inject_sdk_spm (success)"
        vr_log_info "[DEBUG] Listing sandbox after inject_sdk_spm: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -40 || echo '(empty)')"
    fi
    
    # Step 3: Build DemoApp
    vr_log_info "[DEBUG] Entering build_demoapp"
    vr_log_info "[DEBUG] Listing sandbox before build_demoapp: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -40 || echo '(empty)')"
    if ! "$SCRIPT_DIR/build_demoapp.sh" "$SANDBOX_DIR" "$mode"; then
        vr_log_error "[LOCAL] Build failed"
        vr_log_info "[DEBUG] Listing sandbox after build_demoapp FAILED: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -40 || echo '(empty)')"
        LOCAL_VERIFY_SUCCESS=0
        return 0  # Soft-fail
    else
        vr_log_info "[LOCAL] Local verification succeeded"
        vr_log_info "[DEBUG] Listing sandbox after build_demoapp SUCCESS: $(ls -R "$SANDBOX_DIR" 2>/dev/null | head -50 || echo '(empty)')"
        LOCAL_VERIFY_SUCCESS=1
    fi
    
    # Export results for orchestrator
    export LOCAL_VERIFY_EXECUTED
    export LOCAL_VERIFY_SUCCESS
    export LOCAL_VERIFY_MODE
    
    return 0
}

# ============================================================================
# Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_local_verification "$@"
fi


# ---------------------------------------------------------------------
# UTF-8 FIX PATCH
# CocoaPods requires UTF-8 or pod install will crash with:
#   "Unicode Normalization not appropriate for ASCII-8BIT"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export RUBYOPT="-EUTF-8:UTF-8"
vr_log_info "[UTF8] UTF-8 environment applied for pod install"
# ---------------------------------------------------------------------

