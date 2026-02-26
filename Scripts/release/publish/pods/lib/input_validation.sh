#!/usr/bin/env bash
# ============================================================================
# Input Validation Module
# ============================================================================
# Module: input_validation.sh
# Purpose: CLI argument parsing and input validation functions
# Extracted from: publish.sh
#
# Functions:
#   - parse_arguments: Parse CLI arguments for backward compatibility
#   - show_help: Display help message
#   - validate_inputs: Validate required inputs and set defaults
#   - check_release_branch: Verify correct git branch
#
# Dependencies:
#   - Logging functions (log::info, log::error, log::success, log::step)
#
# Environment Variables:
#   - VERSION: Release version (required)
#   - RELEASE_BRANCH: Git release branch
#   - DRY_RUN: If "true", skip actual operations
#   - SKIP_VALIDATION: If "true", skip validation steps
#   - VERBOSE: If "true", enable verbose output
# ============================================================================

set -euo pipefail

# Guard against multiple sourcing
[[ -n "${_INPUT_VALIDATION_SOURCED:-}" ]] && return 0
readonly _INPUT_VALIDATION_SOURCED=1

# ============================================================================
# CLI Argument Parsing
# ============================================================================
# Only used if script is called directly (not via msp-release.sh)
#
# Args:
#   $@: Command line arguments
# ============================================================================
parse_arguments() {
    # Only parse if we have remaining CLI args (backward compatibility)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Modular CocoaPods Release Script v2.0.0-phase2"
                exit 0
                ;;
            --release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --release-notes-source)
                RELEASE_NOTES_SOURCE="$2"
                shift 2
                ;;
            --release-notes-template)
                RELEASE_NOTES_TEMPLATE="$2"
                shift 2
                ;;
            --release-notes)
                RELEASE_NOTES="$2"
                shift 2
                ;;
            *)
                # Unknown argument - ignore (already processed VERSION above)
                shift
                ;;
        esac
    done
}

# ============================================================================
# Show Help
# ============================================================================
# Display usage information and available options
# ============================================================================
show_help() {
    echo "Usage: $0 [OPTIONS] <VERSION>"
    echo ""
    echo "Arguments:"
    echo "  VERSION                 Version to release (e.g., 0.0.2-migration-spm)"
    echo ""
    echo "Options:"
    echo "  --release-branch BRANCH       Release branch to work on (default: release/VERSION)"
    echo "  --dry-run                     Show what would be done without executing"
    echo "  --skip-validation             Skip podspec validation"
    echo "  --verbose                     Enable verbose output"
    echo "  --release-notes-source SOURCE Release notes source (auto, git, template, prompt)"
    echo "  --release-notes-template FILE Custom release notes template file"
    echo "  --release-notes NOTES        Custom release notes text"
    echo "  --help, -h                    Show this help message"
    echo "  --version, -v                 Show version information"
    echo ""
    echo "Release Workflow:"
    echo "  1. Publish MSPSharedLibraries (foundation dependency)"
    echo "  2. Wait for MSPSharedLibraries to be released"
    echo "  3. Publish Adapters (MSPFacebookAdapter, MSPGoogleAdapter, MSPNovaAdapter, MSPAmazonAdapter, MSPPrebidAdapter)"
    echo "  4. Wait for Adapters to be released"
    echo "  5. Publish MSPCore (main framework)"
    echo "  6. Commit all changes to release branch"
}

# ============================================================================
# Validate Inputs
# ============================================================================
# Validate required inputs and set default values
# R005a: Now uses shared_validate_version from shared/input_validation.sh
#
# Returns:
#   0 if valid, exits with 1 if invalid
# ============================================================================
validate_inputs() {
    if [[ -z "${VERSION:-}" ]]; then
        log::error "PODS" "Version is required"
        show_help
        exit 1
    fi

    # R005a: Use shared version validation if available
    if command -v shared_validate_version &>/dev/null; then
        if ! shared_validate_version "$VERSION"; then
            log::error "PODS" "Invalid version format: $VERSION"
            log::error "PODS" "Expected: X.Y.Z or X.Y.Z-suffix (e.g., 1.0.0, 0.0.2-migration-spm)"
            exit 1
        fi
    fi

    # Set release branch if not provided
    # R005a: Use shared_get_release_branch if available
    if [[ -z "${RELEASE_BRANCH:-}" ]]; then
        if command -v shared_get_release_branch &>/dev/null; then
            RELEASE_BRANCH="$(shared_get_release_branch "$VERSION")"
        else
            RELEASE_BRANCH="release/$VERSION"
        fi
    fi

    log::info "PODS" "CocoaPods release configuration:"
    log::info "PODS" "  Version: $VERSION"
    log::info "PODS" "  Release Branch: $RELEASE_BRANCH"
    log::info "PODS" "  Dry Run: ${DRY_RUN:-false}"
    log::info "PODS" "  Skip Validation: ${SKIP_VALIDATION:-false}"
}

# ============================================================================
# Check Release Branch
# ============================================================================
# Verify we're on the correct release branch
# R005b: Now uses shared_validate_branch from shared/input_validation.sh
#
# Returns:
#   0 if on correct branch, exits with 1 if not
# ============================================================================
check_release_branch() {
    log::step "PODS" "Checking release branch"

    # Skip branch check in dry-run mode
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log::info "PODS" "DRY RUN: Skipping release branch check"
        return 0
    fi

    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")

    if [[ -z "$current_branch" ]]; then
        log::error "PODS" "Failed to get current git branch"
        exit 1
    fi

    # R005b: For exact match, check against expected release branch
    if [[ "$current_branch" != "${RELEASE_BRANCH:-}" ]]; then
        # Also allow being on release/* pattern (for flexible workflows)
        if command -v shared_validate_branch &>/dev/null; then
            if ! shared_validate_branch "release/*"; then
                log::error "PODS" "Not on release branch '${RELEASE_BRANCH:-}'. Current branch: '$current_branch'"
                log::info "PODS" "Please checkout the release branch first:"
                log::info "PODS" "  git checkout ${RELEASE_BRANCH:-}"
                exit 1
            fi
            log::warn "PODS" "On release branch '$current_branch' (expected: ${RELEASE_BRANCH:-})"
            return 0
        else
            log::error "PODS" "Not on release branch '${RELEASE_BRANCH:-}'. Current branch: '$current_branch'"
            log::info "PODS" "Please checkout the release branch first:"
            log::info "PODS" "  git checkout ${RELEASE_BRANCH:-}"
            exit 1
        fi
    fi

    log::success "PODS" "On correct release branch: $RELEASE_BRANCH"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f parse_arguments 2>/dev/null || true
export -f show_help 2>/dev/null || true
export -f validate_inputs 2>/dev/null || true
export -f check_release_branch 2>/dev/null || true
