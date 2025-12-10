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
# Inject SDK SPM Dependencies
# ============================================================================
# Purpose: Generate Package.swift with released SDK modules
#
# Usage:   ./inject_sdk_spm.sh <sandbox_path>
#          (reads from .msp-release-state.json)
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# Ensure ROOT_DIR is detected
vr_detect_root_dir || {
    vr_log_error "Failed to detect ROOT_DIR"
    return 1
}

# ============================================================================
# Functions
# ============================================================================

inject_sdk_spm() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local package_path="$demoapp_dir/Package.swift"
    local state_file="$ROOT_DIR/.msp-release-state.json"
    
    # Read released modules from state file
    if [[ ! -f "$state_file" ]]; then
        vr_log_warn "[LOCAL] State file not found, skipping SPM injection"
        return 0
    fi
    
    # Extract version and remote URL from state file
    local version=""
    local remote_url="${MSP_VERIFY_SPM_URL:-}"
    
    if command -v jq >/dev/null 2>&1; then
        version="$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")"
    fi
    
    if [[ -z "$version" ]]; then
        vr_log_warn "[LOCAL] Version not found in state file, skipping SPM injection"
        return 0
    fi
    
    # Default remote URL if not set
    if [[ -z "$remote_url" ]]; then
        remote_url="https://github.com/ParticleMedia/msp-ios-sdk-public.git"
    fi
    
    # Extract SPM modules (default to common modules)
    local spm_modules=("MSPCore")
    
    # Generate Package.swift
    cat > "$package_path" <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DemoAppSPM",
    platforms: [.iOS(.v13)],
    dependencies: [
        .package(url: "$remote_url", exact: "$version")
    ],
    targets: [
        .executableTarget(
            name: "DemoAppSPM",
            dependencies: [
                .product(name: "MSPCore", package: "msp")
            ]
        )
    ]
)
EOF
    
    vr_log_info "[LOCAL] Injected SPM dependencies: URL=$remote_url, version=$version, module=MSPCore"
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inject_sdk_spm "$@"
fi

