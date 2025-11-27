#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK Release System - Unified Entrypoint
# ============================================================================
# Purpose: Single entrypoint for all release operations.
#          Delegates to existing scripts for backward compatibility.
#
# Usage:   ./Scripts/msp-release.sh <command> [options]
#
# Commands:
#   preflight        Validate environment before release (not yet implemented)
#   run <VERSION>    Execute full release (CocoaPods + SPM)
#   pods <VERSION>   Execute CocoaPods release only
#   spm <VERSION>    Execute SPM release only
#   verify <VERSION> Verify a released version (not yet implemented)
#   rollback         Rollback a failed release (not yet implemented)
#   resume           Resume from last checkpoint (not yet implemented)
#
# Examples:
#   ./Scripts/msp-release.sh preflight
#   ./Scripts/msp-release.sh run 0.0.3
#   ./Scripts/msp-release.sh pods 0.0.3 --dry-run
#   ./Scripts/msp-release.sh spm 0.0.3
#
# Phase 1 Note:
#   This is a thin wrapper that delegates to existing scripts.
#   Behavior is unchanged from calling the original scripts directly.
# ============================================================================

set -euo pipefail

# Script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Existing release scripts (Phase 1: delegate to these)
MODULAR_SCRIPT="$SCRIPT_DIR/release/modular.sh"
COCOAPODS_SCRIPT="$SCRIPT_DIR/release/cocoapods.sh"
SPM_SCRIPT="$SCRIPT_DIR/release/spm.sh"

# Version
readonly MSP_RELEASE_VERSION="1.0.0-phase1"

# ============================================================================
# Colors for output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================
log_info() { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✓${NC}  $1"; }
log_error() { echo -e "${RED}✗${NC}  $1" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC}  $1"; }

# ============================================================================
# Show Help
# ============================================================================
show_help() {
    cat << 'EOF'
MSP iOS SDK Release System

USAGE:
    msp-release.sh <COMMAND> [OPTIONS]

COMMANDS:
    preflight           Validate environment before release
    run <VERSION>       Execute full release (CocoaPods + SPM)
    pods <VERSION>      Execute CocoaPods release only
    spm <VERSION>       Execute SPM release only
    verify <VERSION>    Verify a released version
    rollback            Rollback a failed release
    resume              Resume from last checkpoint

OPTIONS:
    All options are passed through to the underlying scripts.
    Common options include:
        --dry-run           Show what would be done without executing
        --verbose           Enable verbose output
        --help, -h          Show this help message
        --version, -v       Show version information

EXAMPLES:
    # Run full release
    msp-release.sh run 0.0.3

    # CocoaPods release with dry-run
    msp-release.sh pods 0.0.3 --dry-run

    # SPM release only
    msp-release.sh spm 0.0.3

    # Pre-flight validation (future)
    msp-release.sh preflight

NOTES:
    Phase 1: This is a thin wrapper around existing release scripts.
    Future phases will add preflight validation, state tracking, and
    a config-driven model (release.yaml).

For more information, see: Docs/RELEASE_SYSTEM_ANALYSIS.md
EOF
}

# ============================================================================
# Show Version
# ============================================================================
show_version() {
    echo "msp-release.sh version $MSP_RELEASE_VERSION"
    echo ""
    echo "Underlying scripts:"
    echo "  modular.sh:   $MODULAR_SCRIPT"
    echo "  cocoapods.sh: $COCOAPODS_SCRIPT"
    echo "  spm.sh:       $SPM_SCRIPT"
}

# ============================================================================
# Command: preflight (not yet implemented)
# ============================================================================
cmd_preflight() {
    log_warn "Command 'preflight' is not yet implemented."
    log_info "This will validate:"
    log_info "  - Git state (clean working tree, correct branch)"
    log_info "  - Podspec validation (lint all podspecs)"
    log_info "  - XCFramework coherence (ThirdParty matches Pods)"
    log_info "  - Package.swift validity"
    log_info "  - Credentials availability (gh, pod trunk)"
    echo ""
    log_info "For now, you can run the CI validation script:"
    log_info "  ./Scripts/ci/ci_validate.sh"
    exit 1
}

# ============================================================================
# Command: run (delegates to modular.sh)
# ============================================================================
cmd_run() {
    local args=("$@")
    
    if [[ ${#args[@]} -eq 0 ]]; then
        log_error "VERSION is required for 'run' command"
        log_info "Usage: msp-release.sh run <VERSION> [OPTIONS]"
        exit 1
    fi
    
    log_info "Delegating to: $MODULAR_SCRIPT"
    log_info "Arguments: ${args[*]}"
    echo ""
    
    exec "$MODULAR_SCRIPT" "${args[@]}"
}

# ============================================================================
# Command: pods (delegates to cocoapods.sh)
# ============================================================================
cmd_pods() {
    local args=("$@")
    
    if [[ ${#args[@]} -eq 0 ]]; then
        log_error "VERSION is required for 'pods' command"
        log_info "Usage: msp-release.sh pods <VERSION> [OPTIONS]"
        exit 1
    fi
    
    log_info "Delegating to: $COCOAPODS_SCRIPT"
    log_info "Arguments: ${args[*]}"
    echo ""
    
    exec "$COCOAPODS_SCRIPT" "${args[@]}"
}

# ============================================================================
# Command: spm (delegates to spm.sh)
# ============================================================================
cmd_spm() {
    local args=("$@")
    
    if [[ ${#args[@]} -eq 0 ]]; then
        log_error "VERSION is required for 'spm' command"
        log_info "Usage: msp-release.sh spm <VERSION> [OPTIONS]"
        exit 1
    fi
    
    log_info "Delegating to: $SPM_SCRIPT"
    log_info "Arguments: ${args[*]}"
    echo ""
    
    exec "$SPM_SCRIPT" "${args[@]}"
}

# ============================================================================
# Command: verify (not yet implemented)
# ============================================================================
cmd_verify() {
    log_warn "Command 'verify' is not yet implemented."
    log_info "This will verify that a release is installable via:"
    log_info "  - pod 'MSPCore', '~> <VERSION>'"
    log_info "  - .package(url: \"...\", from: \"<VERSION>\")"
    exit 1
}

# ============================================================================
# Command: rollback (not yet implemented)
# ============================================================================
cmd_rollback() {
    log_warn "Command 'rollback' is not yet implemented."
    log_info "This will:"
    log_info "  - Delete release tags"
    log_info "  - Delete GitHub releases"
    log_info "  - Unpublish pods (if possible)"
    exit 1
}

# ============================================================================
# Command: resume (not yet implemented)
# ============================================================================
cmd_resume() {
    log_warn "Command 'resume' is not yet implemented."
    log_info "This will resume from the last successful checkpoint."
    log_info "Requires state tracking (future phase)."
    exit 1
}

# ============================================================================
# Main
# ============================================================================
main() {
    # No arguments - show help
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Parse first argument as command
    local command="$1"
    shift
    
    case "$command" in
        preflight)
            cmd_preflight "$@"
            ;;
        run)
            cmd_run "$@"
            ;;
        pods)
            cmd_pods "$@"
            ;;
        spm)
            cmd_spm "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        rollback)
            cmd_rollback "$@"
            ;;
        resume)
            cmd_resume "$@"
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        -v|--version|version)
            show_version
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

