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
# Build DemoApp Using CocoaPods
# ============================================================================
# Purpose: Build DemoApp in sandbox using CocoaPods workspace
#
# Usage:   ./build_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

build_demoapp_pods() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "PODS" "Sandbox path required"
        return 1
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log::warn "PODS" "xcodebuild command not found, skipping build verification"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local workspace="$demoapp_dir/MSPDemoApp.xcworkspace"
    
    if [[ ! -d "$workspace" ]] && [[ ! -L "$workspace" ]]; then
        vr_log::error "PODS" "Workspace not found: $workspace"
        return 1
    fi
    
    # Create temporary log file for xcodebuild output
    local build_log
    build_log="$(mktemp)" || {
        vr_log::error "PODS" "Failed to create temporary log file"
        return 1
    }
    
    # Change to DemoApp directory and run xcodebuild
    pushd "$demoapp_dir" >/dev/null || {
        vr_log::error "PODS" "Failed to change to DemoApp directory: $demoapp_dir"
        rm -f "$build_log"
        return 1
    }
    
    vr_log::info "PODS" "[PODS] Building DemoApp via xcodebuild..."
    if xcodebuild \
        -workspace MSPDemoApp.xcworkspace \
        -scheme MSPDemoApp \
        -configuration Release \
        -sdk iphoneos \
        CODE_SIGNING_ALLOWED=NO \
        >"$build_log" 2>&1; then
        vr_log::info "PODS" "[PODS] Build succeeded"
        rm -f "$build_log"
        popd >/dev/null
        return 0
    else
        vr_log::error "PODS" "[PODS] Build failed"
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
    build_demoapp_pods "$@"
fi
