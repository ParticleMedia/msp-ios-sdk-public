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
# Build DemoApp for Local Verification
# ============================================================================
# Purpose: Build DemoApp using xcodebuild
#
# Usage:   ./build_demoapp.sh <sandbox_path> <mode>
#          mode: "pods" or "spm"
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# R029f: Source xcodegen module for unified generation
_BUILD_DEMOAPP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -f "$_BUILD_DEMOAPP_ROOT/lib/xcodegen.sh" ]]; then
    # shellcheck source=Scripts/lib/xcodegen.sh
    source "$_BUILD_DEMOAPP_ROOT/lib/xcodegen.sh" 2>/dev/null || true
fi

# R036c: Source cocoapods.sh module for unified pod operations
_COCOAPODS_MODULE_AVAILABLE=false
if [[ -f "$_BUILD_DEMOAPP_ROOT/lib/cocoapods.sh" ]]; then
    # shellcheck source=Scripts/lib/cocoapods.sh
    source "$_BUILD_DEMOAPP_ROOT/lib/cocoapods.sh" 2>/dev/null || true
    if command -v install_pods &>/dev/null; then
        _COCOAPODS_MODULE_AVAILABLE=true
    fi
fi

# ============================================================================
# Functions
# ============================================================================

build_demoapp() {
    local sandbox="$1"
    local mode="${2:-pods}"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "LOCAL" "Sandbox path required"
        return 1
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log::warn "LOCAL" "[LOCAL] xcodebuild command not found, skipping build verification"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    
    # For Pods mode, need to run pod install first
    if [[ "$mode" == "pods" ]]; then
        # Ensure DemoApp directory exists
        mkdir -p "$demoapp_dir" || {
            vr_log::error "LOCAL" "[LOCAL] Failed to create DemoApp directory: $demoapp_dir"
            return 1
        }
        
        # Check for Podfile
        if [[ ! -f "$demoapp_dir/Podfile" ]]; then
            vr_log::error "LOCAL" "[LOCAL] Podfile not found at: $demoapp_dir/Podfile"
            vr_log::info "LOCAL" "[LOCAL] DemoApp directory contents:"
            ls -la "$demoapp_dir" 2>/dev/null || vr_log::warn "LOCAL" "[LOCAL] Failed to list DemoApp directory"
            return 1
        fi
        
        # Create pod_install.log in DemoApp directory
        local pod_log="$demoapp_dir/pod_install.log"
        vr_log::info "LOCAL" "[LOCAL] Running pod install in: $demoapp_dir"
        vr_log::info "LOCAL" "[LOCAL] Pod install log: $pod_log"
        
        # ---------------------------------------------------------------------
        # UTF-8 FIX PATCH
        # CocoaPods requires UTF-8 or pod install will crash with:
        #   "Unicode Normalization not appropriate for ASCII-8BIT"
        export LANG="en_US.UTF-8"
        export LC_ALL="en_US.UTF-8"
        export RUBYOPT="-EUTF-8:UTF-8"
        vr_log::info "LOCAL" "[UTF8] UTF-8 environment applied for pod install"
        # ---------------------------------------------------------------------
        # Change to DemoApp directory
        pushd "$demoapp_dir" >/dev/null || {
            vr_log::error "LOCAL" "[LOCAL] Failed to cd into DemoApp dir: $demoapp_dir"
            return 1
        }
        
        # R036c: Use cocoapods.sh module's install_pods() if available
        local pod_success=false
        if [[ "$_COCOAPODS_MODULE_AVAILABLE" == "true" ]]; then
            if install_pods 2>&1 | tee "$pod_log"; then
                pod_success=true
            fi
        else
            # Fallback: Run pod install with verbose output to log file
            if env LANG="en_US.UTF-8" LC_ALL="en_US.UTF-8" RUBYOPT="-EUTF-8:UTF-8" pod install --verbose >"$pod_log" 2>&1; then
                pod_success=true
            fi
        fi

        if [[ "$pod_success" == "true" ]]; then
            vr_log::info "LOCAL" "[LOCAL] pod install succeeded"
        else
            vr_log::error "LOCAL" "[LOCAL] pod install FAILED, see log at: $pod_log"
            tail -n 40 "$pod_log" || cat "$pod_log" || true
            popd >/dev/null || true
            return 1
        fi
        
        popd >/dev/null || true
        
        # Check for workspace
        local workspace="$demoapp_dir/MSPDemoApp.xcworkspace"
        if [[ ! -d "$workspace" ]] && [[ ! -L "$workspace" ]]; then
            vr_log::error "LOCAL" "[LOCAL] Workspace not found: $workspace"
            return 1
        fi
    fi
    
    # Generate Xcode project if needed (using XcodeGen)
    if [[ ! -f "$demoapp_dir/MSPDemoApp.xcodeproj/project.pbxproj" ]]; then
        vr_log::info "LOCAL" "[LOCAL] Generating Xcode project..."
        pushd "$demoapp_dir" >/dev/null || {
            vr_log::error "LOCAL" "[LOCAL] Failed to change to DemoApp directory"
            return 1
        }
        
        if command -v xcodegen >/dev/null 2>&1; then
            # R029f: Use xcodegen.sh module if available, fallback to direct call
            local demoapp_xcodegen_success=false
            if command -v xcodegen_generate &>/dev/null; then
                if xcodegen_generate "project.yml" "." >/dev/null 2>&1; then
                    demoapp_xcodegen_success=true
                fi
            else
                if xcodegen generate >/dev/null 2>&1; then
                    demoapp_xcodegen_success=true
                fi
            fi

            if [[ "$demoapp_xcodegen_success" != "true" ]]; then
                vr_log::error "LOCAL" "[LOCAL] xcodegen failed"
                popd >/dev/null
                return 1
            fi
        else
            vr_log::warn "LOCAL" "[LOCAL] xcodegen not found, cannot generate project"
            popd >/dev/null
            return 1
        fi
        
        popd >/dev/null
    fi
    
    # Create temporary log file for xcodebuild output
    local build_log
    build_log="$(mktemp)" || {
        vr_log::error "LOCAL" "[LOCAL] Failed to create temporary log file"
        return 1
    }
    
    # Change to DemoApp directory and run xcodebuild
    pushd "$demoapp_dir" >/dev/null || {
        vr_log::error "LOCAL" "[LOCAL] Failed to change to DemoApp directory"
        rm -f "$build_log"
        return 1
    }
    
    vr_log::info "LOCAL" "[LOCAL] Building DemoApp via xcodebuild (mode: $mode)..."
    
    # Build command based on mode
    local build_cmd
    if [[ "$mode" == "pods" ]]; then
        build_cmd="xcodebuild -workspace MSPDemoApp.xcworkspace -scheme MSPDemoApp -configuration Release CODE_SIGNING_ALLOWED=NO -quiet"
    else
        build_cmd="xcodebuild -project MSPDemoApp.xcodeproj -scheme MSPDemoApp -configuration Release CODE_SIGNING_ALLOWED=NO -quiet"
    fi
    
    if eval "$build_cmd" >"$build_log" 2>&1; then
        vr_log::info "LOCAL" "[LOCAL] Build succeeded"
        rm -f "$build_log"
        popd >/dev/null
        return 0
    else
        vr_log::error "LOCAL" "[LOCAL] Build failed"
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



