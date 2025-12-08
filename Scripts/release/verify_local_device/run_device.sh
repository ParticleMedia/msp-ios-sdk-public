#!/bin/bash
# ============================================================================
# Device Verification Runner
# ============================================================================
# Purpose: Orchestrate device verification (archive + IPA export)
#
# Usage:   ./run_device.sh
#          (reads MSP_DEVICE_VERIFY_ENABLED, MSP_DEVICE_VERIFY_PODS, MSP_DEVICE_VERIFY_SPM from environment)
# ============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/../verify_remote/common/utils.sh"
# shellcheck source=Scripts/release/verify_remote/common/sandbox.sh
source "$SCRIPT_DIR/../verify_remote/common/sandbox.sh"

# Source device verification scripts
source "$SCRIPT_DIR/prepare_demoapp.sh"
source "$SCRIPT_DIR/inject_sdk_pods.sh"
source "$SCRIPT_DIR/inject_sdk_spm.sh"
source "$SCRIPT_DIR/archive_demoapp.sh"
source "$SCRIPT_DIR/export_ipa.sh"

# ============================================================================
# Environment Variable Defaults
# ============================================================================

# Default: enable all verification if not explicitly disabled
DEVICE_VERIFY_ENABLED="${MSP_DEVICE_VERIFY_ENABLED:-1}"
DEVICE_VERIFY_PODS="${MSP_DEVICE_VERIFY_PODS:-1}"
DEVICE_VERIFY_SPM="${MSP_DEVICE_VERIFY_SPM:-1}"

# Initialize result variables
DEVICE_VERIFY_EXECUTED=0
DEVICE_VERIFY_SUCCESS=0
DEVICE_VERIFY_MODE=""
DEVICE_VERIFY_ARCHIVE_PATH=""
DEVICE_VERIFY_IPA_PATH=""

# ============================================================================
# Main Runner
# ============================================================================

run_device_verification() {
    # Check if device verification is enabled
    if [[ "$DEVICE_VERIFY_ENABLED" != "1" ]]; then
        vr_log_info "[DEVICE] Device verification disabled (MSP_DEVICE_VERIFY_ENABLED != 1)"
        return 0
    fi
    
    # Determine which mode to use (prefer Pods if both enabled)
    local mode=""
    if [[ "$DEVICE_VERIFY_PODS" == "1" ]]; then
        mode="pods"
    elif [[ "$DEVICE_VERIFY_SPM" == "1" ]]; then
        mode="spm"
    else
        vr_log_warn "[DEVICE] Both Pods and SPM are disabled, skipping device verification"
        return 0
    fi
    
    vr_log_info "[DEVICE] Starting device verification (mode: $mode)..."
    DEVICE_VERIFY_EXECUTED=1
    DEVICE_VERIFY_MODE="$mode"
    
    # Create sandbox
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "device")" || {
        vr_log_error "[DEVICE] Failed to create sandbox"
        return 0  # Soft-fail
    }
    
    # Set up trap to clean up sandbox on exit
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    # Step 1: Prepare DemoApp
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "[DEVICE] Failed to prepare DemoApp"
        return 0  # Soft-fail
    fi
    
    # Step 2: Inject SDK dependencies
    if [[ "$mode" == "pods" ]]; then
        if ! "$SCRIPT_DIR/inject_sdk_pods.sh" "$SANDBOX_DIR"; then
            vr_log_error "[DEVICE] Failed to inject Pods dependencies"
            return 0  # Soft-fail
        fi
        
        # Run pod install
        local demoapp_dir="$SANDBOX_DIR/DemoApp"
        if [[ -f "$demoapp_dir/Podfile" ]]; then
            vr_log_info "[DEVICE] Running pod install..."
            pushd "$demoapp_dir" >/dev/null || {
                vr_log_error "[DEVICE] Failed to change to DemoApp directory"
                return 0  # Soft-fail
            }
            if ! pod install --project-directory=. >/dev/null 2>&1; then
                vr_log_error "[DEVICE] pod install failed"
                popd >/dev/null
                return 0  # Soft-fail
            fi
            popd >/dev/null
        fi
        
        # Generate Xcode project if needed
        if [[ ! -f "$demoapp_dir/MSPDemoApp.xcodeproj/project.pbxproj" ]]; then
            vr_log_info "[DEVICE] Generating Xcode project..."
            pushd "$demoapp_dir" >/dev/null || {
                vr_log_error "[DEVICE] Failed to change to DemoApp directory"
                return 0  # Soft-fail
            }
            if command -v xcodegen >/dev/null 2>&1; then
                if ! xcodegen generate >/dev/null 2>&1; then
                    vr_log_error "[DEVICE] xcodegen failed"
                    popd >/dev/null
                    return 0  # Soft-fail
                fi
            else
                vr_log_warn "[DEVICE] xcodegen not found, cannot generate project"
                popd >/dev/null
                return 0  # Soft-fail
            fi
            popd >/dev/null
        fi
    else
        if ! "$SCRIPT_DIR/inject_sdk_spm.sh" "$SANDBOX_DIR"; then
            vr_log_error "[DEVICE] Failed to inject SPM dependencies"
            return 0  # Soft-fail
        fi
        
        # Generate Xcode project if needed
        if [[ ! -f "$demoapp_dir/MSPDemoApp.xcodeproj/project.pbxproj" ]]; then
            vr_log_info "[DEVICE] Generating Xcode project..."
            pushd "$demoapp_dir" >/dev/null || {
                vr_log_error "[DEVICE] Failed to change to DemoApp directory"
                return 0  # Soft-fail
            }
            if command -v xcodegen >/dev/null 2>&1; then
                if ! xcodegen generate >/dev/null 2>&1; then
                    vr_log_error "[DEVICE] xcodegen failed"
                    popd >/dev/null
                    return 0  # Soft-fail
                fi
            else
                vr_log_warn "[DEVICE] xcodegen not found, cannot generate project"
                popd >/dev/null
                return 0  # Soft-fail
            fi
            popd >/dev/null
        fi
    fi
    
    # Step 3: Archive DemoApp
    local archive_path=""
    if ! "$SCRIPT_DIR/archive_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "[DEVICE] Archive failed"
        DEVICE_VERIFY_SUCCESS=0
        return 0  # Soft-fail
    else
        archive_path="$SANDBOX_DIR/DemoApp/DemoApp.xcarchive"
        if [[ -d "$archive_path" ]]; then
            DEVICE_VERIFY_ARCHIVE_PATH="$archive_path"
        fi
    fi
    
    # Step 4: Export IPA
    local ipa_path=""
    if ! "$SCRIPT_DIR/export_ipa.sh" "$SANDBOX_DIR"; then
        vr_log_error "[DEVICE] IPA export failed"
        DEVICE_VERIFY_SUCCESS=0
        return 0  # Soft-fail
    else
        ipa_path="$(find "$SANDBOX_DIR/DemoApp/output" -name "*.ipa" -type f 2>/dev/null | head -1)"
        if [[ -n "$ipa_path" ]] && [[ -f "$ipa_path" ]]; then
            DEVICE_VERIFY_IPA_PATH="$ipa_path"
            vr_log_info "[DEVICE] Device verification succeeded"
            DEVICE_VERIFY_SUCCESS=1
        else
            DEVICE_VERIFY_SUCCESS=0
        fi
    fi
    
    # Export results for orchestrator
    export DEVICE_VERIFY_EXECUTED
    export DEVICE_VERIFY_SUCCESS
    export DEVICE_VERIFY_MODE
    export DEVICE_VERIFY_ARCHIVE_PATH
    export DEVICE_VERIFY_IPA_PATH
    
    return 0
}

# ============================================================================
# Entry Point
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_device_verification "$@"
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

