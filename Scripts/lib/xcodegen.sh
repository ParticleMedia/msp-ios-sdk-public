#!/usr/bin/env bash
# ============================================================================
# XcodeGen Operations Module
# ============================================================================
# Module: xcodegen.sh
# Purpose: Unified XcodeGen project generation and validation
# Created: R028 DRY Refactoring
#
# Functions:
#   - xcodegen_generate: Generate Xcode project from spec
#   - xcodegen_validate_output: Validate generated .xcodeproj
#   - xcodegen_ensure_installed: Ensure xcodegen is available
#
# Config-Driven Environment Variables:
#   - XCODEGEN_SPEC: Default spec file path (default: project.yml)
#   - XCODEGEN_TIMEOUT: Generation timeout in seconds (default: 120)
#
# Dependencies:
#   - xcodegen CLI
#   - Logging functions (optional)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_XCODEGEN_SOURCED:-}" ]] && return 0
readonly _XCODEGEN_SOURCED=1

# ============================================================================
# Configuration
# ============================================================================

XCODEGEN_DEFAULT_SPEC="project.yml"
XCODEGEN_DEFAULT_TIMEOUT=120

# ============================================================================
# Ensure XcodeGen Installed
# ============================================================================
# Checks if xcodegen is available
#
# Returns:
#   0 if available, 1 if not
# ============================================================================
xcodegen_ensure_installed() {
    if command -v xcodegen &>/dev/null; then
        return 0
    fi

    if command -v log::error &>/dev/null; then
        log::error "XCODEGEN" "xcodegen is not installed"
        log::error "XCODEGEN" "Install with: brew install xcodegen"
    fi
    return 1
}

# ============================================================================
# Generate Xcode Project
# ============================================================================
# Generates Xcode project from spec file
#
# Args:
#   $1: spec_path - Path to spec file (default: project.yml)
#   $2: working_dir - Working directory (default: current dir)
#
# Returns:
#   0 if successful, 1 if failed
# ============================================================================
xcodegen_generate() {
    local spec_path="${1:-${XCODEGEN_SPEC:-$XCODEGEN_DEFAULT_SPEC}}"
    local working_dir="${2:-$(pwd)}"
    local timeout="${XCODEGEN_TIMEOUT:-$XCODEGEN_DEFAULT_TIMEOUT}"

    # Ensure xcodegen is available
    if ! xcodegen_ensure_installed; then
        return 1
    fi

    # Validate spec file exists
    local full_spec_path="$spec_path"
    if [[ ! "$spec_path" = /* ]]; then
        full_spec_path="$working_dir/$spec_path"
    fi

    if [[ ! -f "$full_spec_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "XCODEGEN" "Spec file not found: $full_spec_path"
        fi
        return 1
    fi

    if command -v log::info &>/dev/null; then
        log::info "XCODEGEN" "Generating Xcode project..."
        log::info "XCODEGEN" "  Spec: $spec_path"
        log::info "XCODEGEN" "  Directory: $working_dir"
    fi

    # Run xcodegen
    local output
    local exit_code=0

    if [[ "$working_dir" != "$(pwd)" ]]; then
        output=$(cd "$working_dir" && timeout "$timeout" xcodegen generate --spec "$spec_path" 2>&1) || exit_code=$?
    else
        output=$(timeout "$timeout" xcodegen generate --spec "$spec_path" 2>&1) || exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        if command -v log::success &>/dev/null; then
            log::success "XCODEGEN" "✓ Xcode project generated successfully"
        fi
        return 0
    else
        if command -v log::error &>/dev/null; then
            log::error "XCODEGEN" "Failed to generate Xcode project (exit code: $exit_code)"
            log::error "XCODEGEN" "Output: $output"
        fi
        return 1
    fi
}

# ============================================================================
# Validate Generated Project
# ============================================================================
# Validates that .xcodeproj was generated correctly
#
# Args:
#   $1: xcodeproj_path - Path to .xcodeproj directory
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
xcodegen_validate_output() {
    local xcodeproj_path="$1"

    # Check .xcodeproj exists
    if [[ ! -d "$xcodeproj_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "XCODEGEN" ".xcodeproj not found: $xcodeproj_path"
        fi
        return 1
    fi

    # Check project.pbxproj exists
    if [[ ! -f "$xcodeproj_path/project.pbxproj" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "XCODEGEN" "project.pbxproj not found in: $xcodeproj_path"
        fi
        return 1
    fi

    # Check file is not empty
    if [[ ! -s "$xcodeproj_path/project.pbxproj" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "XCODEGEN" "project.pbxproj is empty: $xcodeproj_path"
        fi
        return 1
    fi

    if command -v log::success &>/dev/null; then
        log::success "XCODEGEN" "✓ Xcode project validated: $(basename "$xcodeproj_path")"
    fi
    return 0
}

# ============================================================================
# Generate and Validate
# ============================================================================
# Convenience function to generate and validate in one call
#
# Args:
#   $1: spec_path - Path to spec file
#   $2: xcodeproj_path - Expected output .xcodeproj path
#   $3: working_dir - Working directory (optional)
#
# Returns:
#   0 if successful, 1 if failed
# ============================================================================
xcodegen_generate_and_validate() {
    local spec_path="$1"
    local xcodeproj_path="$2"
    local working_dir="${3:-$(pwd)}"

    if ! xcodegen_generate "$spec_path" "$working_dir"; then
        return 1
    fi

    if ! xcodegen_validate_output "$xcodeproj_path"; then
        return 1
    fi

    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f xcodegen_ensure_installed 2>/dev/null || true
export -f xcodegen_generate 2>/dev/null || true
export -f xcodegen_validate_output 2>/dev/null || true
export -f xcodegen_generate_and_validate 2>/dev/null || true
