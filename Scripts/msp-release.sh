#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK Release System - Unified Entrypoint
# ============================================================================
# Purpose: Single entrypoint for all release operations.
#          Supports config-driven releases via release.yaml.
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
# Config-Driven Mode:
#   ./Scripts/msp-release.sh run --config release.yaml
#   ./Scripts/msp-release.sh run 0.0.3 --config custom-release.yaml
#
# Override Priority (highest to lowest):
#   1. CLI flags (--skip-pods, VERSION argument, etc.)
#   2. Config file values (release.yaml)
#   3. Built-in defaults
#
# Examples:
#   ./Scripts/msp-release.sh preflight
#   ./Scripts/msp-release.sh run 0.0.3
#   ./Scripts/msp-release.sh run --config Scripts/release/config/release.yaml
#   ./Scripts/msp-release.sh pods 0.0.3 --dry-run
#   ./Scripts/msp-release.sh spm 0.0.3
#
# Phase 2 Note:
#   This version adds config-driven releases via release.yaml.
#   Underlying scripts (modular.sh, cocoapods.sh, spm.sh) still use their own logic.
# ============================================================================

set -euo pipefail

# Script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Existing release scripts (delegate to these)
MODULAR_SCRIPT="$SCRIPT_DIR/release/modular.sh"
COCOAPODS_SCRIPT="$SCRIPT_DIR/release/cocoapods.sh"
SPM_SCRIPT="$SCRIPT_DIR/release/spm.sh"

# Default config file location
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/release/config/release.yaml"

# Version
readonly MSP_RELEASE_VERSION="1.1.0-phase2"

# ============================================================================
# Source Config Module
# ============================================================================
if [[ -f "$SCRIPT_DIR/release/utils/config.sh" ]]; then
    # shellcheck source=Scripts/release/utils/config.sh
    source "$SCRIPT_DIR/release/utils/config.sh"
    CONFIG_MODULE_LOADED=true
else
    CONFIG_MODULE_LOADED=false
fi

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
log_debug() { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${CYAN}🔍${NC} $1" || true; }

# ============================================================================
# Global Options (set by parse_global_options)
# ============================================================================
VERBOSE=false
DRY_RUN=false
CONFIG_FILE=""
CLI_VERSION=""
CLI_SKIP_PODS=false
CLI_SKIP_SPM=false

# ============================================================================
# Parse Global Options
# ============================================================================
# Extracts global options (--config, --verbose, --dry-run) from arguments.
# Returns remaining arguments for command-specific processing.
parse_global_options() {
    # Initialize REMAINING_ARGS as empty
    REMAINING_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    log_error "--config requires a file path"
                    exit 1
                fi
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            --verbose|-V)
                VERBOSE=true
                REMAINING_ARGS+=("$1")  # Pass through to underlying script
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                REMAINING_ARGS+=("$1")  # Pass through to underlying script
                shift
                ;;
            --skip-cocoapods|--skip-pods)
                CLI_SKIP_PODS=true
                REMAINING_ARGS+=("$1")  # Pass through to underlying script
                shift
                ;;
            --skip-spm)
                CLI_SKIP_SPM=true
                REMAINING_ARGS+=("$1")  # Pass through to underlying script
                shift
                ;;
            *)
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# ============================================================================
# Load Release Configuration
# ============================================================================
# Loads YAML config file and exports environment variables for later phases.
# Implements override priority: CLI args > YAML config > built-in defaults
# ============================================================================
load_release_config() {
    # If config module is not available, skip config loading (backward compatibility)
    if [[ "$CONFIG_MODULE_LOADED" != "true" ]]; then
        log_debug "[CONFIG] Config module not available - using CLI arguments only"
        return 0
    fi
    
    # Initialize defaults from config.sh
    init_config_defaults
    
    # Load config file if --config was provided
    if [[ -n "$CONFIG_FILE" ]]; then
        # Validate config file exists
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "Config file not found: $CONFIG_FILE"
            exit 1
        fi
        
        # Resolve absolute path for clarity
        local config_abs_path
        config_abs_path="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
        
        log_debug "[CONFIG] Loading config from: $config_abs_path"
        
        # Parse YAML config file
        if ! load_config "$CONFIG_FILE"; then
            log_error "Failed to parse config file: $CONFIG_FILE"
            exit 1
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "[CONFIG] Loaded from: $config_abs_path"
        fi
    else
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "[CONFIG] No config file specified - using defaults"
        fi
    fi
    
    # Apply CLI overrides (CLI takes precedence over config)
    if [[ -n "$CLI_VERSION" ]]; then
        log_debug "[CONFIG] CLI override: version=$CLI_VERSION"
        set_config_version "$CLI_VERSION"
    fi
    
    if [[ "$CLI_SKIP_PODS" == "true" ]]; then
        log_debug "[CONFIG] CLI override: pods.enabled=false"
        set_config_pods_enabled "false"
    fi
    
    if [[ "$CLI_SKIP_SPM" == "true" ]]; then
        log_debug "[CONFIG] CLI override: spm.enabled=false"
        set_config_spm_enabled "false"
    fi
    
    # Validate config (warnings only, not fatal)
    validate_config || true
    
    # Export environment variables for later phases
    # These variables will be available to orchestrator scripts
    export RELEASE_VERSION="$(get_config_version)"
    export RELEASE_BRANCH="$(get_config_release_branch)"
    export BASE_BRANCH="$(get_config_base_branch)"
    export PODS_ENABLED="$(get_config_pods_enabled)"
    export SPM_ENABLED="$(get_config_spm_enabled)"
    export PODS_MODULES="$(get_config_pods_modules)"
    export SPM_PACKAGES="$(get_config_spm_packages)"
    export SLACK_CHANNEL="$(get_config_slack_channel)"
    export DM_ON_FAILURE="$(get_config_dm_on_failure)"
    
    # Print verbose debug output in requested format
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "[CONFIG] Configuration Summary:"
        echo "[CONFIG]   version = ${RELEASE_VERSION:-<not set>}"
        echo "[CONFIG]   release_branch = ${RELEASE_BRANCH:-<auto>}"
        echo "[CONFIG]   base_branch = ${BASE_BRANCH:-main}"
        echo "[CONFIG]   pods.enabled = ${PODS_ENABLED:-true}"
        echo "[CONFIG]   pods.modules = ${PODS_MODULES:-<default>}"
        echo "[CONFIG]   spm.enabled = ${SPM_ENABLED:-true}"
        echo "[CONFIG]   spm.packages = ${SPM_PACKAGES:-<default>}"
        echo "[CONFIG]   notifications.slack_channel = ${SLACK_CHANNEL:-#msp-release}"
        echo "[CONFIG]   notifications.dm_on_failure = ${DM_ON_FAILURE:-true}"
        echo ""
    fi
}

# ============================================================================
# Load and Apply Config (Alias for backward compatibility)
# ============================================================================
# This function is kept for backward compatibility with existing code.
# It now delegates to load_release_config().
# ============================================================================
load_and_apply_config() {
    load_release_config
}

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
    --config <file>     Load release configuration from YAML file
    --verbose, -V       Enable verbose output (includes config summary)
    --dry-run           Show what would be done without executing
    --skip-pods         Skip CocoaPods release
    --skip-spm          Skip SPM release
    --help, -h          Show this help message
    --version, -v       Show version information

CONFIG-DRIVEN RELEASES:
    Instead of passing VERSION as argument, you can use a config file:

    # Create a release config
    cp Scripts/release/config/release.yaml my-release.yaml
    # Edit my-release.yaml to set version and options
    
    # Run release using config
    msp-release.sh run --config my-release.yaml
    
    # Config with CLI overrides (CLI wins)
    msp-release.sh run 0.0.4 --config my-release.yaml

OVERRIDE PRIORITY (highest to lowest):
    1. CLI flags (VERSION argument, --skip-pods, etc.)
    2. Config file values (release.yaml)
    3. Built-in defaults

EXAMPLES:
    # Run full release with version
    msp-release.sh run 0.0.3

    # Run release using config file
    msp-release.sh run --config Scripts/release/config/release.yaml

    # Run with config + verbose
    msp-release.sh run --config release.yaml --verbose

    # CocoaPods release with dry-run
    msp-release.sh pods 0.0.3 --dry-run

    # SPM release only
    msp-release.sh spm 0.0.3

    # Skip SPM, use config for everything else
    msp-release.sh run --config release.yaml --skip-spm

CONFIG FILE FORMAT (release.yaml):
    version: "0.0.3"
    base_branch: "main"
    pods:
      enabled: true
      modules:
        - MSPSharedLibraries
        - MSPCore
    spm:
      enabled: true
      packages:
        - NovaCore
    notifications:
      slack_channel: "#msp-release"

For more information, see:
    - Docs/RELEASE_SYSTEM_ANALYSIS.md
    - Scripts/release/config/release.yaml (default config template)
EOF
}

# ============================================================================
# Show Version
# ============================================================================
show_version() {
    echo "msp-release.sh version $MSP_RELEASE_VERSION"
    echo ""
    echo "Features:"
    echo "  - Config module: $(if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then echo "loaded"; else echo "not available"; fi)"
    echo "  - Default config: $DEFAULT_CONFIG_FILE"
    echo ""
    echo "Underlying scripts:"
    echo "  modular.sh:   $MODULAR_SCRIPT"
    echo "  cocoapods.sh: $COCOAPODS_SCRIPT"
    echo "  spm.sh:       $SPM_SCRIPT"
}

# ============================================================================
# Command: config (show current config)
# ============================================================================
cmd_config() {
    if [[ "$CONFIG_MODULE_LOADED" != "true" ]]; then
        log_error "Config module not available"
        exit 1
    fi
    
    parse_global_options "$@"
    
    # Temporarily disable verbose to prevent double printing
    local save_verbose="$VERBOSE"
    VERBOSE=false
    load_and_apply_config
    VERBOSE="$save_verbose"
    
    # Always print config summary for 'config' command
    print_config_summary
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        print_config_debug
    fi
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
    parse_global_options "$@"
    set -- ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
    
    # Load config (applies CLI overrides)
    load_and_apply_config
    
    # Get version: CLI arg > config > error
    local version=""
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        version="$1"
        shift
        # Update config with CLI version
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$version"
        fi
    elif [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
        version=$(get_config_version)
    fi
    
    if [[ -z "$version" ]]; then
        log_error "VERSION is required for 'run' command"
        log_info "Usage: msp-release.sh run <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh run --config <file>  (with version in config)"
        exit 1
    fi
    
    # Build arguments for modular.sh
    local args=("$version")
    
    # Add remaining CLI args (--dry-run, --verbose, etc.)
    args+=("$@")
    
    # Add config-derived flags (only if not already set by CLI)
    if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
        if [[ "$(get_config_pods_enabled)" == "false" && "$CLI_SKIP_PODS" == "false" ]]; then
            args+=("--skip-cocoapods")
        fi
        if [[ "$(get_config_spm_enabled)" == "false" && "$CLI_SKIP_SPM" == "false" ]]; then
            args+=("--skip-spm")
        fi
    fi
    
    log_info "Delegating to: $MODULAR_SCRIPT"
    log_info "Arguments: ${args[*]}"
    
    if [[ "$VERBOSE" == "true" && "$CONFIG_MODULE_LOADED" == "true" ]]; then
        echo ""
        log_info "Config-derived settings:"
        log_info "  Pods modules: $(get_config_pods_modules)"
        log_info "  SPM packages: $(get_config_spm_packages)"
        log_info "  Base branch: $(get_config_base_branch)"
    fi
    
    echo ""
    
    exec "$MODULAR_SCRIPT" "${args[@]}"
}

# ============================================================================
# Command: pods (delegates to cocoapods.sh)
# ============================================================================
cmd_pods() {
    parse_global_options "$@"
    set -- ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
    
    # Load config
    load_and_apply_config
    
    # Get version: CLI arg > config > error
    local version=""
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        version="$1"
        shift
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$version"
        fi
    elif [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
        version=$(get_config_version)
    fi
    
    if [[ -z "$version" ]]; then
        log_error "VERSION is required for 'pods' command"
        log_info "Usage: msp-release.sh pods <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh pods --config <file>  (with version in config)"
        exit 1
    fi
    
    # Build arguments
    local args=("$version" "$@")
    
    log_info "Delegating to: $COCOAPODS_SCRIPT"
    log_info "Arguments: ${args[*]}"
    
    if [[ "$VERBOSE" == "true" && "$CONFIG_MODULE_LOADED" == "true" ]]; then
        echo ""
        log_info "Config-derived settings:"
        log_info "  Pods modules: $(get_config_pods_modules)"
    fi
    
    echo ""
    
    exec "$COCOAPODS_SCRIPT" "${args[@]}"
}

# ============================================================================
# Command: spm (delegates to spm.sh)
# ============================================================================
cmd_spm() {
    parse_global_options "$@"
    set -- ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
    
    # Load config
    load_and_apply_config
    
    # Get version: CLI arg > config > error
    local version=""
    if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        version="$1"
        shift
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$version"
        fi
    elif [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
        version=$(get_config_version)
    fi
    
    if [[ -z "$version" ]]; then
        log_error "VERSION is required for 'spm' command"
        log_info "Usage: msp-release.sh spm <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh spm --config <file>  (with version in config)"
        exit 1
    fi
    
    # Build arguments
    local args=("$version" "$@")
    
    log_info "Delegating to: $SPM_SCRIPT"
    log_info "Arguments: ${args[*]}"
    
    if [[ "$VERBOSE" == "true" && "$CONFIG_MODULE_LOADED" == "true" ]]; then
        echo ""
        log_info "Config-derived settings:"
        log_info "  SPM packages: $(get_config_spm_packages)"
    fi
    
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
        config)
            cmd_config "$@"
            ;;
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
