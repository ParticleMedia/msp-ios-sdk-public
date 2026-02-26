#!/usr/bin/env bash
# ============================================================================
# Verification Sandbox Module
# ============================================================================
# Module: sandbox.sh
# Purpose: Manage isolated sandbox environments for verification testing
# Created for: T060
#
# Functions:
#   - sandbox_create: Create isolated sandbox directory
#   - sandbox_cleanup: Clean up sandbox on success
#   - sandbox_get_path: Get current sandbox path
#   - sandbox_is_active: Check if sandbox is active
#
# Dependencies:
#   - Logging functions (log_info, log_error, log_success, log_warning)
#
# Environment Variables:
#   - MSP_SANDBOX_DIR: Custom sandbox base directory (default: /tmp/msp-verify)
#   - MSP_SANDBOX_KEEP: Keep sandbox after success (default: false)
#   - DEBUG/VERBOSE: Keep sandbox for inspection
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SANDBOX_SOURCED:-}" ]] && return 0
readonly _SANDBOX_SOURCED=1

# ============================================================================
# Module State
# ============================================================================

_SANDBOX_CURRENT_PATH=""

_SANDBOX_TRAP_REGISTERED=false

# ============================================================================
# Module Initialization
# ============================================================================

_sandbox_init() {
    # Verify logging functions are available
    if ! command -v log_info &>/dev/null; then
        echo "[ERROR] Logging functions not available. Source logger.sh first." >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Public API
# ============================================================================

# Create isolated sandbox directory
# @description Creates a timestamped sandbox directory for verification tests
# @param $1 name - Optional name suffix (e.g., "pods", "spm")
# @return 0 if success, 1 if failure
# @env MSP_SANDBOX_DIR - Base directory (default: /tmp/msp-verify)
# @side-effect Sets _SANDBOX_CURRENT_PATH
sandbox_create() {
    local name="${1:-verify}"
    local base_dir="${MSP_SANDBOX_DIR:-/tmp/msp-verify}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    local sandbox_path="$base_dir/${name}-${timestamp}-$$"

    log::info "SANDBOX" "Creating verification sandbox: $sandbox_path"

    if ! mkdir -p "$sandbox_path"; then
        log::error "SANDBOX" "Failed to create sandbox directory: $sandbox_path"
        return 1
    fi

    if [[ ! -d "$sandbox_path" ]]; then
        log::error "SANDBOX" "Sandbox directory not created: $sandbox_path"
        return 1
    fi

    _SANDBOX_CURRENT_PATH="$sandbox_path"
    export MSP_SANDBOX_CURRENT="$sandbox_path"

    if [[ "$_SANDBOX_TRAP_REGISTERED" != "true" ]]; then
        trap '_sandbox_auto_cleanup' EXIT
        _SANDBOX_TRAP_REGISTERED=true
    fi

    log::success "SANDBOX" "Sandbox created: $sandbox_path"
    echo "$sandbox_path"
    return 0
}

# Clean up sandbox directory
# @description Removes sandbox directory and its contents
# @param $1 path - Optional specific path (defaults to current sandbox)
# @return 0 if success, 1 if failure
# @env MSP_SANDBOX_KEEP - Keep sandbox if "true"
# @env DEBUG/VERBOSE - Keep sandbox for inspection
sandbox_cleanup() {
    local path="${1:-$_SANDBOX_CURRENT_PATH}"

    # Skip if no path
    if [[ -z "$path" ]]; then
        log::warn "SANDBOX" "No sandbox path to clean up"
        return 0
    fi

    # Check keep flags
    if [[ "${MSP_SANDBOX_KEEP:-false}" == "true" ]]; then
        log::info "SANDBOX" "Keeping sandbox (MSP_SANDBOX_KEEP=true): $path"
        return 0
    fi

    if [[ "${DEBUG:-false}" == "true" ]] || [[ "${VERBOSE:-false}" == "true" ]]; then
        log::info "SANDBOX" "Keeping sandbox for inspection (DEBUG/VERBOSE mode): $path"
        return 0
    fi

    # Verify path is safe to remove (must be under expected base)
    local base_dir="${MSP_SANDBOX_DIR:-/tmp/msp-verify}"
    if [[ "$path" != "$base_dir"* ]]; then
        log::error "SANDBOX" "Refusing to remove path outside sandbox base: $path"
        return 1
    fi

    # Additional safety: never remove system directories
    case "$path" in
        /|/usr|/var|/etc|/home|/Users|/tmp)
            log::error "SANDBOX" "Refusing to remove system directory: $path"
            return 1
            ;;
    esac

    log::info "SANDBOX" "Cleaning up sandbox: $path"

    if rm -rf "$path" 2>/dev/null; then
        log::success "SANDBOX" "Sandbox cleaned up: $path"
        _SANDBOX_CURRENT_PATH=""
        unset MSP_SANDBOX_CURRENT
        return 0
    else
        log::warn "SANDBOX" "Failed to clean up sandbox: $path"
        return 1
    fi
}

# Get current sandbox path
# @description Returns the current active sandbox path
# @return Path string via stdout, 1 if no sandbox active
sandbox_get_path() {
    if [[ -n "$_SANDBOX_CURRENT_PATH" ]]; then
        echo "$_SANDBOX_CURRENT_PATH"
        return 0
    else
        return 1
    fi
}

# Check if sandbox is active
# @description Returns 0 if sandbox is active, 1 otherwise
# @return 0 if active, 1 if not
sandbox_is_active() {
    [[ -n "$_SANDBOX_CURRENT_PATH" && -d "$_SANDBOX_CURRENT_PATH" ]]
}

# Create subdirectory in sandbox
# @description Creates a subdirectory within the current sandbox
# @param $1 subdir - Subdirectory name (e.g., "TestApp", "build")
# @return Path via stdout, 1 if failure
sandbox_mkdir() {
    local subdir="$1"

    if [[ -z "$_SANDBOX_CURRENT_PATH" ]]; then
        log::error "SANDBOX" "No active sandbox. Call sandbox_create first."
        return 1
    fi

    local full_path="$_SANDBOX_CURRENT_PATH/$subdir"

    if mkdir -p "$full_path"; then
        echo "$full_path"
        return 0
    else
        log::error "SANDBOX" "Failed to create sandbox subdirectory: $full_path"
        return 1
    fi
}

# Copy file into sandbox
# @description Copies a file into the current sandbox
# @param $1 source - Source file path
# @param $2 dest - Destination path relative to sandbox (optional)
# @return 0 if success, 1 if failure
sandbox_copy() {
    local source="$1"
    local dest="${2:-$(basename "$source")}"

    if [[ -z "$_SANDBOX_CURRENT_PATH" ]]; then
        log::error "SANDBOX" "No active sandbox. Call sandbox_create first."
        return 1
    fi

    local full_dest="$_SANDBOX_CURRENT_PATH/$dest"

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$full_dest")
    mkdir -p "$parent_dir"

    if cp -r "$source" "$full_dest"; then
        return 0
    else
        log::error "SANDBOX" "Failed to copy to sandbox: $source -> $full_dest"
        return 1
    fi
}

# ============================================================================
# Internal Functions
# ============================================================================

# Auto cleanup on exit (trap handler)
_sandbox_auto_cleanup() {
    local exit_code=$?

    # Only clean up on success (exit code 0)
    if [[ $exit_code -eq 0 ]]; then
        if sandbox_is_active; then
            sandbox_cleanup
        fi
    else
        if sandbox_is_active; then
            log::warn "SANDBOX" "Keeping sandbox due to non-zero exit: $_SANDBOX_CURRENT_PATH"
        fi
    fi

    return $exit_code
}

# ============================================================================
# Export Functions
# ============================================================================

export -f sandbox_create
export -f sandbox_cleanup
export -f sandbox_get_path
export -f sandbox_is_active
export -f sandbox_mkdir
export -f sandbox_copy
