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
# Prepare DemoApp for Local Verification
# ============================================================================
# Purpose: Copy DemoApp into sandbox directory for local verification
#
# Usage:   ./prepare_demoapp.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# Ensure ROOT_DIR is detected
vr_detect_root_dir || {
    vr_log_error "Failed to detect ROOT_DIR"
    exit 1
}

# ============================================================================
# Functions
# ============================================================================

prepare_demoapp() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "[LOCAL] Sandbox path required"
        return 1
    fi
    
    # Ensure ROOT_DIR is set (re-detect if needed)
    if [[ -z "${ROOT_DIR:-}" ]]; then
        vr_detect_root_dir || {
            vr_log_error "[LOCAL] Failed to detect ROOT_DIR"
            return 1
        }
    fi
    
    # Compute source and destination paths
    local demoapp_src="$ROOT_DIR/Examples/MSPDemoApp"
    local demoapp_dst="$sandbox/DemoApp"
    
    vr_log_info "[LOCAL] ROOT_DIR: $ROOT_DIR"
    vr_log_info "[LOCAL] Source path: $demoapp_src"
    vr_log_info "[LOCAL] Destination path: $demoapp_dst"
    
    # Hard check: source must exist
    if [[ ! -d "$demoapp_src" ]]; then
        vr_log_error "[LOCAL] DemoApp source not found: $demoapp_src"
        vr_log_info "[LOCAL] ROOT_DIR value: ${ROOT_DIR:-<unset>}"
        vr_log_info "[LOCAL] Current directory: $(pwd)"
        return 1
    fi
    
    # Remove destination if it exists (to ensure clean copy)
    if [[ -d "$demoapp_dst" ]]; then
        rm -rf "$demoapp_dst" || {
            vr_log_error "[LOCAL] Failed to remove existing DemoApp dest dir: $demoapp_dst"
            return 1
        }
    fi
    
    # Copy entire DemoApp directory - simplest and most reliable method
    vr_log_info "[LOCAL] Executing: cp -R \"$demoapp_src\" \"$demoapp_dst\""
    if ! cp -R "$demoapp_src" "$demoapp_dst" 2>&1; then
        vr_log_error "[LOCAL] Failed to copy DemoApp from $demoapp_src to $demoapp_dst"
        vr_log_info "[LOCAL] Source directory exists: $([ -d "$demoapp_src" ] && echo 'YES' || echo 'NO')"
        vr_log_info "[LOCAL] Source directory contents:"
        ls -la "$demoapp_src" 2>/dev/null | head -20 || true
        return 1
    fi
    
    # Verify the copy succeeded
    if [[ ! -d "$demoapp_dst" ]]; then
        vr_log_error "[LOCAL] DemoApp destination directory missing after copy: $demoapp_dst"
        return 1
    fi
    
    # Count files to verify copy
    local file_count
    file_count="$(find "$demoapp_dst" -type f 2>/dev/null | wc -l | tr -d ' ' || echo '0')"
    vr_log_info "[LOCAL] Copy completed. File count: $file_count"
    
    if [[ "$file_count" == "0" ]]; then
        vr_log_error "[LOCAL] Copy completed but destination is empty (0 files found)"
        vr_log_info "[LOCAL] Source file count: $(find "$demoapp_src" -type f 2>/dev/null | wc -l | tr -d ' ' || echo '0')"
        vr_log_info "[LOCAL] Destination directory listing:"
        ls -la "$demoapp_dst" 2>/dev/null || true
        return 1
    fi
    
    vr_log_info "[LOCAL] Copied DemoApp sources to sandbox: $demoapp_dst ($file_count files)"
    
    # List contents (non-fatal if it fails)
    vr_log_info "[LOCAL] Verifying copy (listing contents):"
    ls -R "$demoapp_dst" 2>/dev/null | head -30 || vr_log_warn "[LOCAL] Could not list DemoApp directory (non-fatal)"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    prepare_demoapp "$@"
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

