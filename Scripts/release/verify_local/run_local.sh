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
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "local")" || {
        vr_log_error "[LOCAL] Failed to create sandbox"
        return 0  # Soft-fail
    }
    
    # Set up trap to clean up sandbox on exit
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    # Step 1: Prepare DemoApp
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "[LOCAL] Failed to prepare DemoApp"
        return 0  # Soft-fail
    fi
    
    # Step 2: Inject SDK dependencies
    if [[ "$mode" == "pods" ]]; then
        if ! "$SCRIPT_DIR/inject_sdk_pods.sh" "$SANDBOX_DIR"; then
            vr_log_error "[LOCAL] Failed to inject Pods dependencies"
            return 0  # Soft-fail
        fi
    else
        if ! "$SCRIPT_DIR/inject_sdk_spm.sh" "$SANDBOX_DIR"; then
            vr_log_error "[LOCAL] Failed to inject SPM dependencies"
            return 0  # Soft-fail
        fi
    fi
    
    # Step 3: Build DemoApp
    if ! "$SCRIPT_DIR/build_demoapp.sh" "$SANDBOX_DIR" "$mode"; then
        vr_log_error "[LOCAL] Build failed"
        LOCAL_VERIFY_SUCCESS=0
        return 0  # Soft-fail
    else
        vr_log_info "[LOCAL] Local verification succeeded"
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

