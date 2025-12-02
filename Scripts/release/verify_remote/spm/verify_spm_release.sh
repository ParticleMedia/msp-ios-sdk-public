#!/bin/bash
# ============================================================================
# SPM Remote Release Verification Orchestrator
# ============================================================================
# Purpose: Orchestrate complete SPM remote release verification
#
# Usage:   ./verify_spm_release.sh
#          (reads MSP_VERIFY_SPM_URL, MSP_VERIFY_SPM_VERSION from environment)
# ============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Scripts/release/verify_remote/common/utils.sh
source "$SCRIPT_DIR/../common/utils.sh"
# shellcheck source=Scripts/release/verify_remote/common/sandbox.sh
source "$SCRIPT_DIR/../common/sandbox.sh"

# Source SPM verification scripts
source "$SCRIPT_DIR/prepare_demoapp.sh"
source "$SCRIPT_DIR/parse_remote_package.sh"
source "$SCRIPT_DIR/patch_package.swift.sh"
source "$SCRIPT_DIR/build_demoapp.sh"

# ============================================================================
# Main Verification Flow
# ============================================================================

verify_spm_release() {
    # Sanity check: swift command must be available
    if ! command -v swift >/dev/null 2>&1; then
        vr_log_warn "swift command not found, skipping SPM verification"
        return 0
    fi
    
    # Read configuration from environment
    local remote_url="${MSP_VERIFY_SPM_URL:-}"
    local remote_version="${MSP_VERIFY_SPM_VERSION:-}"
    local module_name="${MSP_VERIFY_SPM_MODULE:-MSPCore}"
    
    # Check if required environment variables are set
    if [[ -z "$remote_url" ]] || [[ -z "$remote_version" ]]; then
        vr_log_warn "SPM remote verification skipped (missing MSP_VERIFY_SPM_URL / MSP_VERIFY_SPM_VERSION)"
        return 0
    fi
    
    # Create sandbox
    local SANDBOX_DIR
    SANDBOX_DIR="$(vr_create_sandbox "spm")" || {
        vr_log_error "Failed to create sandbox"
        return 1
    }
    
    # Set up trap to clean up sandbox on exit
    # Use a function to capture SANDBOX_DIR in the trap
    local cleanup_sandbox_path="$SANDBOX_DIR"
    trap "vr_cleanup_sandbox '$cleanup_sandbox_path'" EXIT
    
    # Call scripts in order
    vr_log_info "Starting SPM remote verification (URL=$remote_url, version=$remote_version)"
    
    # Step 1: Prepare DemoApp
    if ! "$SCRIPT_DIR/prepare_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to prepare DemoApp"
        return 1
    fi
    
    # Step 2: Parse remote Package.swift
    vr_log_info "[SPM] Parsing remote Package.swift..."
    # Source the script to get the function, then call it
    source "$SCRIPT_DIR/parse_remote_package.sh"
    if ! parse_remote_package "$SANDBOX_DIR" "$remote_url"; then
        vr_log_warn "[SPM] Remote package analysis failed — skipping SPM verify"
        return 0
    fi
    
    # Check if parsing succeeded
    if [[ -z "${REMOTE_PACKAGE_NAME:-}" ]] || [[ -z "${REMOTE_PRODUCT_NAME:-}" ]]; then
        vr_log_warn "[SPM] Remote package analysis failed (missing package/product name) — skipping SPM verify"
        return 0
    fi
    
    # Step 3: Patch Package.swift (using parsed values)
    if ! "$SCRIPT_DIR/patch_package.swift.sh" "$SANDBOX_DIR" "$remote_url" "$remote_version"; then
        vr_log_error "Failed to patch Package.swift"
        return 1
    fi
    
    # Step 4: Build DemoApp
    if ! "$SCRIPT_DIR/build_demoapp.sh" "$SANDBOX_DIR"; then
        vr_log_error "Failed to build DemoApp"
        return 1
    fi
    
    # On success, log completion
    vr_log_info "SPM remote verification (URL=$remote_url, version=$remote_version) completed successfully."
    
    return 0
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_spm_release "$@"
fi

