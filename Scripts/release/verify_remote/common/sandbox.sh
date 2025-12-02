#!/bin/bash
# ============================================================================
# Sandbox Management for Remote Verification
# ============================================================================
# Purpose: Create and manage isolated sandbox directories for verification
#
# Usage:   source "$(dirname "$0")/sandbox.sh"
# ============================================================================

set -euo pipefail

# Source common utilities
# Use absolute path resolution to handle being sourced from different directories
SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR_COMMON/utils.sh"

# ============================================================================
# Sandbox Creation
# ============================================================================

vr_create_sandbox() {
    local label="${1:-verify}"
    
    # Ensure ROOT_DIR is detected
    if ! vr_detect_root_dir; then
        vr_log_error "Cannot create sandbox: ROOT_DIR detection failed"
        return 1
    fi
    
    # Create temp dir under /tmp: /tmp/msp-remote-verify-<label>-XXXXXX
    local sandbox_template="/tmp/msp-remote-verify-${label}-XXXXXX"
    local sandbox_path
    sandbox_path="$(mktemp -d "$sandbox_template" 2>/dev/null || echo "")"
    
    if [[ -z "$sandbox_path" ]]; then
        vr_log_error "Failed to create sandbox directory"
        return 1
    fi
    
    # Log friendly message
    vr_log_info "Created sandbox: $sandbox_path"
    
    # Echo the sandbox path to stdout (no extra text)
    echo "$sandbox_path"
    return 0
}

# ============================================================================
# Sandbox Cleanup
# ============================================================================

vr_cleanup_sandbox() {
    local dir="${1:-}"
    
    if [[ -n "$dir" && -d "$dir" ]]; then
        rm -rf "$dir" || true
        vr_log_info "Sandbox cleaned: $dir"
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f vr_create_sandbox vr_cleanup_sandbox 2>/dev/null || true

