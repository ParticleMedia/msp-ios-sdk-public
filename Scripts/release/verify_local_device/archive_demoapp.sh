#!/bin/bash
# ============================================================================
# Archive DemoApp for Device Verification
# ============================================================================
# Purpose: Archive DemoApp using xcodebuild
#
# Usage:   ./archive_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

archive_demoapp() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log_warn "[DEVICE] xcodebuild command not found, skipping archive"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    
    # Check for workspace (Pods mode) or project (SPM mode)
    local workspace="$demoapp_dir/MSPDemoApp.xcworkspace"
    local project="$demoapp_dir/MSPDemoApp.xcodeproj"
    
    # Determine build target
    local build_target=""
    if [[ -d "$workspace" ]] || [[ -L "$workspace" ]]; then
        build_target="-workspace MSPDemoApp.xcworkspace"
    elif [[ -d "$project" ]]; then
        build_target="-project MSPDemoApp.xcodeproj"
    else
        vr_log_error "[DEVICE] Neither workspace nor project found"
        return 1
    fi
    
    # Create temporary log file for xcodebuild output
    local build_log
    build_log="$(mktemp)" || {
        vr_log_error "[DEVICE] Failed to create temporary log file"
        return 1
    }
    
    # Change to DemoApp directory and run xcodebuild archive
    pushd "$demoapp_dir" >/dev/null || {
        vr_log_error "[DEVICE] Failed to change to DemoApp directory"
        rm -f "$build_log"
        return 1
    }
    
    vr_log_info "[DEVICE] Archiving DemoApp via xcodebuild..."
    
    # Archive command
    local archive_path="$demoapp_dir/DemoApp.xcarchive"
    if xcodebuild \
        $build_target \
        -scheme MSPDemoApp \
        -configuration Release \
        -sdk iphoneos \
        -archivePath "$archive_path" \
        CODE_SIGNING_ALLOWED=NO \
        clean archive \
        >"$build_log" 2>&1; then
        
        # Verify archive exists
        if [[ -d "$archive_path" ]]; then
            vr_log_info "[DEVICE] Archive succeeded: $archive_path"
            rm -f "$build_log"
            popd >/dev/null
            return 0
        else
            vr_log_error "[DEVICE] Archive directory not found after build"
            echo "---------- XCODEBUILD OUTPUT (last 80 lines) ----------"
            tail -n 80 "$build_log" || cat "$build_log"
            echo "------------------------------------------------------"
            rm -f "$build_log"
            popd >/dev/null
            return 1
        fi
    else
        vr_log_error "[DEVICE] Archive failed"
        echo "---------- XCODEBUILD OUTPUT (last 80 lines) ----------"
        tail -n 80 "$build_log" || cat "$build_log"
        echo "------------------------------------------------------"
        rm -f "$build_log"
        popd >/dev/null
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    archive_demoapp "$@"
fi

