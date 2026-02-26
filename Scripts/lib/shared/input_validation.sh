#!/usr/bin/env bash
# ============================================================================
# Shared Input Validation Module
# ============================================================================
# Module: shared/input_validation.sh
# Purpose: Common CLI argument parsing and input validation for release scripts
#
# Functions:
#   - shared_parse_common_args: Parse common CLI arguments (dry-run, verbose, etc.)
#   - shared_validate_version: Validate version string format
#   - shared_validate_branch: Validate git branch
#   - shared_get_release_branch: Get release branch name from version
#   - shared_ensure_project_root: Ensure we're in project root
#
# Config-Driven:
#   - Uses environment variables as primary source
#   - Falls back to CLI arguments for backward compatibility
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::warn)
#   - Git CLI
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_SHARED_INPUT_VALIDATION_SOURCED:-}" ]] && return 0
readonly _SHARED_INPUT_VALIDATION_SOURCED=1

# ============================================================================
# Version Validation
# ============================================================================
# Validates version string format
#
# Args:
#   $1: version - Version string to validate
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
shared_validate_version() {
    local version="${1:-}"

    # Empty version is invalid
    if [[ -z "$version" ]]; then
        return 1
    fi

    # Version must match pattern: X.Y.Z or X.Y.Z-suffix
    # Examples: 1.0.0, 0.0.2-migration-spm, 1.2.3-beta.1
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?$ ]]; then
        return 0
    fi

    return 1
}

# ============================================================================
# Get Release Branch Name
# ============================================================================
# Generates release branch name from version
#
# Args:
#   $1: version - Version string
#
# Returns:
#   Prints release branch name (release/VERSION)
# ============================================================================
shared_get_release_branch() {
    local version="${1:-}"
    echo "release/${version}"
}

# ============================================================================
# Branch Validation
# ============================================================================
# Validates current git branch for release operations
#
# Args:
#   $1: allowed_patterns - Space-separated list of allowed branch patterns
#                          (default: "main master release/* feature/*")
#
# Returns:
#   0 if valid, 1 if invalid
# ============================================================================
shared_validate_branch() {
    local allowed_patterns="${1:-main master release/* feature/*}"
    local current_branch

    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

    if [[ -z "$current_branch" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SHARED" "Could not determine current git branch"
        fi
        return 1
    fi

    # shellcheck disable=SC2086 -- intentional word-splitting: allowed_patterns is a space-delimited glob pattern list
    for pattern in $allowed_patterns; do
        # shellcheck disable=SC2053
        if [[ "$current_branch" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# ============================================================================
# Ensure Project Root
# ============================================================================
# Ensures we're in the project root directory
#
# Returns:
#   0 if in project root, 1 if not
# ============================================================================
shared_ensure_project_root() {
    local root_dir="${ROOT_DIR:-}"

    if [[ -z "$root_dir" ]]; then
        root_dir="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
    fi

    if [[ -z "$root_dir" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SHARED" "Could not determine project root"
        fi
        return 1
    fi

    if [[ ! -d "$root_dir/.git" ]]; then
        if command -v log::error &>/dev/null; then
            log::error "SHARED" "Not in a git repository: $root_dir"
        fi
        return 1
    fi

    return 0
}

# ============================================================================
# Parse Common Arguments
# ============================================================================
# Parses common CLI arguments shared across release scripts
# Sets global variables: DRY_RUN, VERBOSE, RELEASE_BRANCH, RELEASE_NOTES
#
# Args:
#   $@: CLI arguments
#
# Returns:
#   Remaining arguments (after removing parsed ones)
# ============================================================================
shared_parse_common_args() {
    # Initialize defaults from environment (config-driven)
    DRY_RUN="${DRY_RUN:-false}"
    VERBOSE="${VERBOSE:-false}"
    RELEASE_BRANCH="${RELEASE_BRANCH:-}"
    RELEASE_NOTES="${RELEASE_NOTES:-}"

    local remaining_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-branch)
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    RELEASE_BRANCH="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --release-notes)
                if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                    RELEASE_NOTES="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Export for subprocesses
    export DRY_RUN VERBOSE RELEASE_BRANCH RELEASE_NOTES

    # Return remaining args
    if [[ ${#remaining_args[@]} -gt 0 ]]; then
        echo "${remaining_args[@]}"
    fi
}

# ============================================================================
# Print Common Configuration
# ============================================================================
# Prints common configuration for debugging
#
# Args:
#   $1: script_name - Name of the calling script (e.g., "SPM", "PODS")
#   $2: version - Version being released
# ============================================================================
shared_print_config() {
    local script_name="${1:-RELEASE}"
    local version="${2:-}"

    if command -v log::info &>/dev/null; then
        log::info "$script_name" "Release configuration:"
        log::info "$script_name" "  Version: ${version:-not set}"
        log::info "$script_name" "  Release Branch: ${RELEASE_BRANCH:-auto}"
        log::info "$script_name" "  Dry Run: ${DRY_RUN:-false}"
        log::info "$script_name" "  Verbose: ${VERBOSE:-false}"
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f shared_validate_version 2>/dev/null || true
export -f shared_get_release_branch 2>/dev/null || true
export -f shared_validate_branch 2>/dev/null || true
export -f shared_ensure_project_root 2>/dev/null || true
export -f shared_parse_common_args 2>/dev/null || true
export -f shared_print_config 2>/dev/null || true
