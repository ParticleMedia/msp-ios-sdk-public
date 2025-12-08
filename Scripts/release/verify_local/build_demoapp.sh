#!/bin/bash
# ============================================================================
# Build DemoApp for Local Verification
# ============================================================================
# Purpose: Build DemoApp using xcodebuild
#
# Usage:   ./build_demoapp.sh <sandbox_path> <mode>
#          mode: "pods" or "spm"
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

build_demoapp() {
    local sandbox="$1"
    local mode="${2:-pods}"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log_warn "[LOCAL] xcodebuild command not found, skipping build verification"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    
    # For Pods mode, need to run pod install first
    if [[ "$mode" == "pods" ]]; then
        # Ensure DemoApp directory exists
        mkdir -p "$demoapp_dir" || {
            vr_log_error "[LOCAL] Failed to create DemoApp directory: $demoapp_dir"
            return 1
        }
        
        # Check for Podfile
        if [[ ! -f "$demoapp_dir/Podfile" ]]; then
            vr_log_error "[LOCAL] Podfile not found at: $demoapp_dir/Podfile"
            vr_log_info "[LOCAL] DemoApp directory contents:"
            ls -la "$demoapp_dir" 2>/dev/null || vr_log_warn "[LOCAL] Failed to list DemoApp directory"
            return 1
        fi
        
        # Create pod_install.log in DemoApp directory
        local pod_log="$demoapp_dir/pod_install.log"
        vr_log_info "[LOCAL] Running pod install in: $demoapp_dir"
        vr_log_info "[LOCAL] Pod install log: $pod_log"
        
        # ---------------------------------------------------------------------
        # UTF-8 FIX PATCH
        # CocoaPods requires UTF-8 or pod install will crash with:
        #   "Unicode Normalization not appropriate for ASCII-8BIT"
        export LANG="en_US.UTF-8"
        export LC_ALL="en_US.UTF-8"
        export RUBYOPT="-EUTF-8:UTF-8"
        vr_log_info "[UTF8] UTF-8 environment applied for pod install"
        # ---------------------------------------------------------------------
        # Change to DemoApp directory
        pushd "$demoapp_dir" >/dev/null || {
            vr_log_error "[LOCAL] Failed to cd into DemoApp dir: $demoapp_dir"
            return 1
        }
        
        # Run pod install with verbose output to log file
        if env LANG="en_US.UTF-8" LC_ALL="en_US.UTF-8" RUBYOPT="-EUTF-8:UTF-8" pod install --verbose >"$pod_log" 2>&1; then
            vr_log_info "[LOCAL] pod install succeeded"
        else
            vr_log_error "[LOCAL] pod install FAILED, see log at: $pod_log"
            tail -n 40 "$pod_log" || cat "$pod_log" || true
            popd >/dev/null || true
            return 1
        fi
        
        popd >/dev/null || true
        
        # Check for workspace
        local workspace="$demoapp_dir/MSPDemoApp.xcworkspace"
        if [[ ! -d "$workspace" ]] && [[ ! -L "$workspace" ]]; then
            vr_log_error "[LOCAL] Workspace not found: $workspace"
            return 1
        fi
    fi
    
    # Generate Xcode project if needed (using XcodeGen)
    if [[ ! -f "$demoapp_dir/MSPDemoApp.xcodeproj/project.pbxproj" ]]; then
        vr_log_info "[LOCAL] Generating Xcode project..."
        pushd "$demoapp_dir" >/dev/null || {
            vr_log_error "[LOCAL] Failed to change to DemoApp directory"
            return 1
        }
        
        if command -v xcodegen >/dev/null 2>&1; then
            if ! xcodegen generate >/dev/null 2>&1; then
                vr_log_error "[LOCAL] xcodegen failed"
                popd >/dev/null
                return 1
            fi
        else
            vr_log_warn "[LOCAL] xcodegen not found, cannot generate project"
            popd >/dev/null
            return 1
        fi
        
        popd >/dev/null
    fi
    
    # Create temporary log file for xcodebuild output
    local build_log
    build_log="$(mktemp)" || {
        vr_log_error "[LOCAL] Failed to create temporary log file"
        return 1
    }
    
    # Change to DemoApp directory and run xcodebuild
    pushd "$demoapp_dir" >/dev/null || {
        vr_log_error "[LOCAL] Failed to change to DemoApp directory"
        rm -f "$build_log"
        return 1
    }
    
    vr_log_info "[LOCAL] Building DemoApp via xcodebuild (mode: $mode)..."
    
    # Build command based on mode
    local build_cmd
    if [[ "$mode" == "pods" ]]; then
        build_cmd="xcodebuild -workspace MSPDemoApp.xcworkspace -scheme MSPDemoApp -configuration Release CODE_SIGNING_ALLOWED=NO -quiet"
    else
        build_cmd="xcodebuild -project MSPDemoApp.xcodeproj -scheme MSPDemoApp -configuration Release CODE_SIGNING_ALLOWED=NO -quiet"
    fi
    
    if eval "$build_cmd" >"$build_log" 2>&1; then
        vr_log_info "[LOCAL] Build succeeded"
        rm -f "$build_log"
        popd >/dev/null
        return 0
    else
        vr_log_error "[LOCAL] Build failed"
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
    build_demoapp "$@"
fi



