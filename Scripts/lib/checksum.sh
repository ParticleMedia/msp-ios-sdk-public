#!/usr/bin/env bash
# ============================================================================
# Checksum Calculation Module
# ============================================================================
# Module: checksum.sh
# Purpose: Cross-platform SHA256 checksum calculation and verification
# Created: R030 DRY Refactoring
#
# Functions:
#   - checksum_compute_sha256: Compute SHA256 hash of a file
#   - checksum_validate_format: Validate hash format (64-char hex)
#   - checksum_verify_file: Verify file against expected hash
#
# Platform Support:
#   - macOS: Uses shasum -a 256
#   - Linux: Uses sha256sum
#   - Fallback: swift package compute-checksum (for .zip files)
#
# Dependencies:
#   - shasum or sha256sum CLI
#   - Logging functions (optional)
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_CHECKSUM_SOURCED:-}" ]] && return 0
readonly _CHECKSUM_SOURCED=1

# ============================================================================
# Compute SHA256 Hash
# ============================================================================
# Cross-platform SHA256 hash computation
#
# Args:
#   $1: file_path - Path to file
#
# Returns:
#   Prints 64-character hex hash to stdout
#   Returns 1 if file not found or command fails
# ============================================================================
checksum_compute_sha256() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "CHECKSUM" "File not found: $file_path"
        fi
        return 1
    fi

    local hash=""

    # Try shasum first (macOS, some Linux)
    if command -v shasum &>/dev/null; then
        hash=$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}')
    # Try sha256sum (Linux)
    elif command -v sha256sum &>/dev/null; then
        hash=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}')
    # Fallback to swift for .zip files
    elif [[ "$file_path" =~ \.zip$ ]] && command -v swift &>/dev/null; then
        hash=$(swift package compute-checksum "$file_path" 2>/dev/null)
    else
        if command -v log::error &>/dev/null; then
            log::error "CHECKSUM" "No SHA256 tool available (shasum, sha256sum, or swift)"
        fi
        return 1
    fi

    # Validate hash was computed
    if [[ -z "$hash" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "CHECKSUM" "Failed to compute checksum for: $file_path"
        fi
        return 1
    fi

    echo "$hash"
}

# ============================================================================
# Validate Hash Format
# ============================================================================
# Validates that a string is a valid SHA256 hash (64 hex characters)
#
# Args:
#   $1: hash - Hash string to validate
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
checksum_validate_format() {
    local hash="$1"

    # SHA256 hash must be exactly 64 lowercase hex characters
    if [[ "$hash" =~ ^[a-f0-9]{64}$ ]]; then
        return 0
    fi

    return 1
}

# ============================================================================
# Verify File Against Expected Hash
# ============================================================================
# Computes hash and compares against expected value
#
# Args:
#   $1: file_path - Path to file
#   $2: expected_hash - Expected SHA256 hash
#
# Returns:
#   0 if match, 1 if mismatch or error
# ============================================================================
checksum_verify_file() {
    local file_path="$1"
    local expected_hash="$2"

    # Validate expected hash format
    if ! checksum_validate_format "$expected_hash"; then
        if command -v log::error &>/dev/null; then
            log::error "CHECKSUM" "Invalid expected hash format: $expected_hash"
        fi
        return 1
    fi

    # Compute actual hash
    local actual_hash
    if ! actual_hash=$(checksum_compute_sha256 "$file_path"); then
        return 1
    fi

    # Compare
    if [[ "$actual_hash" == "$expected_hash" ]]; then
        if command -v log::success &>/dev/null; then
            log::success "CHECKSUM" "✓ Checksum verified: $(basename "$file_path")"
        fi
        return 0
    else
        if command -v log::error &>/dev/null; then
            log::error "CHECKSUM" "Checksum mismatch for: $(basename "$file_path")"
            log::error "CHECKSUM" "  Expected: $expected_hash"
            log::error "CHECKSUM" "  Actual:   $actual_hash"
        fi
        return 1
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f checksum_compute_sha256 2>/dev/null || true
export -f checksum_validate_format 2>/dev/null || true
export -f checksum_verify_file 2>/dev/null || true
