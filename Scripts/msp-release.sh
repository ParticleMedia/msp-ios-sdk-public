#!/usr/bin/env bash
# ============================================================================
# MSP iOS SDK Release System - Unified Entrypoint
# ============================================================================
# Purpose: Single entrypoint for all release operations.
#          Supports config-driven releases via release.yaml.
#
# Phase 2 Step 3: Complete CLI framework implementation
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
readonly MSP_RELEASE_VERSION="1.2.0-phase2-step3"

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
# Colors for output (can be disabled with --no-ansi)
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================================
# Subcommand Registry
# ============================================================================
# All supported subcommands
readonly SUBCOMMANDS=(
    "help"
    "version"
    "config"
    "preflight"
    "run"
    "pods"
    "spm"
    "verify"
    "rollback"
    "resume"
)

# ============================================================================
# Global Flag Variables (initialized to defaults)
# ============================================================================
VERBOSE=false
DRY_RUN=false
NO_ANSI=false
SKIP_PREFLIGHT=false
SKIP_PODS=false
SKIP_SPM=false
ONLY_PODS=false
ONLY_SPM=false
CONFIG_FILE=""
CLI_VERSION=""
SUBCOMMAND=""

# ============================================================================
# CLI Logging Helpers (respect VERBOSE and NO_ANSI)
# ============================================================================
cli_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        if [[ "$NO_ANSI" == "true" ]]; then
            echo "[DEBUG] $1"
        else
            echo -e "${CYAN}🔍${NC} $1"
        fi
    fi
}

cli_info() {
    if [[ "$NO_ANSI" == "true" ]]; then
        echo "[INFO] $1"
    else
        echo -e "${BLUE}ℹ${NC}  $1"
    fi
}

cli_success() {
    if [[ "$NO_ANSI" == "true" ]]; then
        echo "[OK] $1"
    else
        echo -e "${GREEN}✓${NC}  $1"
    fi
}

cli_warn() {
    if [[ "$NO_ANSI" == "true" ]]; then
        echo "[WARN] $1" >&2
    else
        echo -e "${YELLOW}⚠${NC}  $1" >&2
    fi
}

cli_error() {
    if [[ "$NO_ANSI" == "true" ]]; then
        echo "[ERROR] $1" >&2
    else
        echo -e "${RED}✗${NC}  $1" >&2
    fi
}

# Legacy logging functions (for backward compatibility)
log_info() { cli_info "$1"; }
log_success() { cli_success "$1"; }
log_error() { cli_error "$1"; }
log_warn() { cli_warn "$1"; }
log_debug() { cli_debug "$1"; }

# ============================================================================
# Flag Parser
# ============================================================================
# Parses all flags from arguments, supports flags before and after subcommand
# Returns remaining arguments (subcommand + positional args)
parse_flags() {
    REMAINING_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    cli_error "--config requires a file path"
                    exit 1
                fi
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            --verbose|-V)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-ansi)
                NO_ANSI=true
                shift
                ;;
            --skip-preflight)
                SKIP_PREFLIGHT=true
                shift
                ;;
            --skip-pods|--skip-cocoapods)
                SKIP_PODS=true
                shift
                ;;
            --skip-spm)
                SKIP_SPM=true
                shift
                ;;
            --only-pods)
                ONLY_PODS=true
                SKIP_SPM=true
                shift
                ;;
            --only-spm)
                ONLY_SPM=true
                SKIP_PODS=true
                shift
                ;;
            --version|-v)
                # Special case: if this is the only arg, show version and exit
                if [[ $# -eq 1 ]]; then
                    SUBCOMMAND="version"
                    return 0
                fi
                # Otherwise, treat as flag and continue
                shift
                ;;
            --help|-h)
                # Special case: if this is the only arg, show help and exit
                if [[ $# -eq 1 ]]; then
                    SUBCOMMAND="help"
                    return 0
                fi
                # Otherwise, treat as flag and continue
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
# Subcommand Detection
# ============================================================================
# Detects subcommand from remaining args, handles backward compatibility
detect_subcommand() {
    local args=("$@")
    
    # If no args, default to help
    if [[ ${#args[@]} -eq 0 ]]; then
        SUBCOMMAND="help"
        return 0
    fi
    
    local first="${args[0]}"
    
    # Check if first arg is a known subcommand
    for cmd in "${SUBCOMMANDS[@]}"; do
        if [[ "$first" == "$cmd" ]]; then
            SUBCOMMAND="$cmd"
            REMAINING_ARGS=("${args[@]:1}")
            return 0
        fi
    done
    
    # Backward compatibility: if first arg looks like a version number,
    # treat it as "run <version>"
    if [[ "$first" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        SUBCOMMAND="run"
        CLI_VERSION="$first"
        REMAINING_ARGS=("${args[@]:1}")
        return 0
    fi
    
    # If first arg is a flag we already processed, default to "run"
    if [[ "$first" =~ ^-- ]]; then
        SUBCOMMAND="run"
        REMAINING_ARGS=("${args[@]}")
        return 0
    fi
    
    # Unknown command
    SUBCOMMAND="$first"
    REMAINING_ARGS=("${args[@]:1}")
}

# ============================================================================
# Apply CLI Overrides
# ============================================================================
# Applies CLI flag values into exported config values
# Implements priority: CLI flags > config file > built-in defaults
apply_cli_overrides() {
    # Version override
    if [[ -n "$CLI_VERSION" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$CLI_VERSION"
        fi
        cli_debug "[CLI] Override: RELEASE_VERSION=$CLI_VERSION"
    fi
    
    # Pods enabled override
    if [[ "$SKIP_PODS" == "true" ]]; then
        export PODS_ENABLED="false"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_pods_enabled "false"
        fi
        cli_debug "[CLI] Override: PODS_ENABLED=false"
    elif [[ "$ONLY_PODS" == "true" ]]; then
        export PODS_ENABLED="true"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_pods_enabled "true"
        fi
        cli_debug "[CLI] Override: PODS_ENABLED=true (only-pods)"
    fi
    
    # SPM enabled override
    if [[ "$SKIP_SPM" == "true" ]]; then
        export SPM_ENABLED="false"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_spm_enabled "false"
        fi
        cli_debug "[CLI] Override: SPM_ENABLED=false"
    elif [[ "$ONLY_SPM" == "true" ]]; then
        export SPM_ENABLED="true"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_spm_enabled "true"
        fi
        cli_debug "[CLI] Override: SPM_ENABLED=true (only-spm)"
    fi
    
    # Export other CLI flags
    export DRY_RUN="$DRY_RUN"
    export VERBOSE="$VERBOSE"
    export SKIP_PREFLIGHT="$SKIP_PREFLIGHT"
    export NO_ANSI="$NO_ANSI"
    
    cli_debug "[CLI] Applied all CLI overrides"
}

# ============================================================================
# Load Release Configuration
# ============================================================================
# Loads YAML config file and exports environment variables for later phases.
# Implements override priority: CLI args > YAML config > built-in defaults
load_release_config() {
    # If config module is not available, skip config loading (backward compatibility)
    if [[ "$CONFIG_MODULE_LOADED" != "true" ]]; then
        cli_debug "[CONFIG] Config module not available - using CLI arguments only"
        return 0
    fi
    
    # Initialize defaults from config.sh
    init_config_defaults
    
    # Load config file if --config was provided
    if [[ -n "$CONFIG_FILE" ]]; then
        # Validate config file exists
        if [[ ! -f "$CONFIG_FILE" ]]; then
            cli_error "Config file not found: $CONFIG_FILE"
            exit 1
        fi
        
        # Resolve absolute path for clarity
        local config_abs_path
        config_abs_path="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
        
        cli_debug "[CONFIG] Loading config from: $config_abs_path"
        
        # Parse YAML config file
        if ! load_config "$CONFIG_FILE"; then
            cli_error "Failed to parse config file: $CONFIG_FILE"
            exit 1
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            cli_info "[CONFIG] Loaded from: $config_abs_path"
        fi
    else
        if [[ "$VERBOSE" == "true" ]]; then
            cli_info "[CONFIG] No config file specified - using defaults"
        fi
    fi
    
    # Validate config (warnings only, not fatal)
    validate_config || true
    
    # Export environment variables from config (before CLI overrides)
    export RELEASE_VERSION="$(get_config_version)"
    export RELEASE_BRANCH="$(get_config_release_branch)"
    export BASE_BRANCH="$(get_config_base_branch)"
    export PODS_ENABLED="$(get_config_pods_enabled)"
    export SPM_ENABLED="$(get_config_spm_enabled)"
    export PODS_MODULES="$(get_config_pods_modules)"
    export SPM_PACKAGES="$(get_config_spm_packages)"
    export SLACK_CHANNEL="$(get_config_slack_channel)"
    export DM_ON_FAILURE="$(get_config_dm_on_failure)"
    
    # Apply CLI overrides (CLI takes precedence)
    apply_cli_overrides
    
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

# Alias for backward compatibility
load_and_apply_config() {
    load_release_config
}

# ============================================================================
# Unified Help System
# ============================================================================
show_help() {
    cat << EOF
MSP iOS SDK Release System

USAGE:
    msp-release.sh [GLOBAL_FLAGS] <COMMAND> [COMMAND_ARGS]

COMMANDS:
    help              Show this help message
    version           Show CLI version information
    config            Print effective configuration (merged CLI > config > defaults)
    preflight         Validate environment before release
    run <VERSION>     Execute full release (CocoaPods + SPM)
    pods <VERSION>    Execute CocoaPods release only
    spm <VERSION>     Execute SPM release only
    verify <VERSION>  Verify a released version (post-release validation)
    rollback          Rollback a failed release
    resume            Resume from last checkpoint

GLOBAL FLAGS:
    --config <file>       Load release configuration from YAML file
    --verbose, -V         Enable verbose output (includes config summary)
    --dry-run             Show what would be done without executing
    --no-ansi             Disable colored output
    --skip-preflight      Skip preflight validation
    --skip-pods           Skip CocoaPods release
    --skip-spm            Skip SPM release
    --only-pods           Only run CocoaPods release (implies --skip-spm)
    --only-spm            Only run SPM release (implies --skip-pods)
    --version, -v         Show version information
    --help, -h            Show this help message

OVERRIDE PRIORITY (highest to lowest):
    1. CLI flags (VERSION argument, --skip-pods, etc.)
    2. Config file values (release.yaml)
    3. Built-in defaults

EXAMPLES:
    # Show help
    msp-release.sh help
    msp-release.sh --help

    # Show version
    msp-release.sh version
    msp-release.sh --version

    # Show effective config
    msp-release.sh config
    msp-release.sh config --config release.yaml --verbose

    # Run full release with version
    msp-release.sh run 0.0.3
    msp-release.sh 0.0.3                    # Backward compatibility

    # Run release using config file
    msp-release.sh run --config Scripts/release/config/release.yaml

    # Run with flags (before or after subcommand)
    msp-release.sh --verbose run 0.0.3
    msp-release.sh run 0.0.3 --verbose

    # CocoaPods release only
    msp-release.sh pods 0.0.3
    msp-release.sh run 0.0.3 --only-pods

    # SPM release only
    msp-release.sh spm 0.0.3
    msp-release.sh run 0.0.3 --only-spm

    # Dry run
    msp-release.sh run 0.0.3 --dry-run

    # Preflight validation
    msp-release.sh preflight

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
      dm_on_failure: true

For more information, see:
    - Scripts/release/config/release.yaml.template
    - Docs/RELEASE_SYSTEM_ANALYSIS.md
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
# Subcommand Handlers (Placeholders for Phase 2 Step 3)
# ============================================================================

do_help() {
    show_help
}

do_version() {
    show_version
}

do_config() {
    if [[ "$CONFIG_MODULE_LOADED" != "true" ]]; then
        cli_error "Config module not available"
        exit 1
    fi
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Print config summary
    print_config_summary
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        print_config_debug
    fi
}

do_preflight() {
    cli_info "[CLI] preflight subcommand invoked (no logic yet)"
    cli_warn "Command 'preflight' is not yet implemented."
    cli_info "This will validate:"
    cli_info "  - Git state (clean working tree, correct branch)"
    cli_info "  - Podspec validation (lint all podspecs)"
    cli_info "  - XCFramework coherence (ThirdParty matches Pods)"
    cli_info "  - Package.swift validity"
    cli_info "  - Credentials availability (gh, pod trunk)"
    exit 0
}

do_run() {
    cli_info "[CLI] run subcommand invoked"
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get version from remaining args or config
    if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        CLI_VERSION="${REMAINING_ARGS[0]}"
        REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$CLI_VERSION"
        fi
    fi
    
    # Apply version override
    if [[ -n "$CLI_VERSION" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        apply_cli_overrides
    fi
    
    # Check if version is set
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        cli_error "VERSION is required for 'run' command"
        cli_info "Usage: msp-release.sh run <VERSION> [OPTIONS]"
        cli_info "   or: msp-release.sh run --config <file>  (with version in config)"
        exit 1
    fi
    
    # For now, delegate to modular.sh (backward compatibility)
    cli_info "Delegating to: $MODULAR_SCRIPT"
    cli_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    exec "$MODULAR_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

do_pods() {
    cli_info "[CLI] pods subcommand invoked"
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get version from remaining args or config
    if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        CLI_VERSION="${REMAINING_ARGS[0]}"
        REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$CLI_VERSION"
        fi
    fi
    
    # Apply version override
    if [[ -n "$CLI_VERSION" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        apply_cli_overrides
    fi
    
    # Check if version is set
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        cli_error "VERSION is required for 'pods' command"
        cli_info "Usage: msp-release.sh pods <VERSION> [OPTIONS]"
        cli_info "   or: msp-release.sh pods --config <file>  (with version in config)"
        exit 1
    fi
    
    # For now, delegate to cocoapods.sh (backward compatibility)
    cli_info "Delegating to: $COCOAPODS_SCRIPT"
    cli_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    exec "$COCOAPODS_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

do_spm() {
    cli_info "[CLI] spm subcommand invoked"
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get version from remaining args or config
    if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        CLI_VERSION="${REMAINING_ARGS[0]}"
        REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$CLI_VERSION"
        fi
    fi
    
    # Apply version override
    if [[ -n "$CLI_VERSION" ]]; then
        export RELEASE_VERSION="$CLI_VERSION"
        apply_cli_overrides
    fi
    
    # Check if version is set
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        cli_error "VERSION is required for 'spm' command"
        cli_info "Usage: msp-release.sh spm <VERSION> [OPTIONS]"
        cli_info "   or: msp-release.sh spm --config <file>  (with version in config)"
        exit 1
    fi
    
    # For now, delegate to spm.sh (backward compatibility)
    cli_info "Delegating to: $SPM_SCRIPT"
    cli_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    exec "$SPM_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

do_verify() {
    cli_info "[CLI] verify subcommand invoked (no logic yet)"
    cli_warn "Command 'verify' is not yet implemented."
    cli_info "This will verify that a release is installable via:"
    cli_info "  - pod 'MSPCore', '~> <VERSION>'"
    cli_info "  - .package(url: \"...\", from: \"<VERSION>\")"
    exit 0
}

do_rollback() {
    cli_info "[CLI] rollback subcommand invoked (no logic yet)"
    cli_warn "Command 'rollback' is not yet implemented."
    cli_info "This will:"
    cli_info "  - Delete release tags"
    cli_info "  - Delete GitHub releases"
    cli_info "  - Unpublish pods (if possible)"
    exit 0
}

do_resume() {
    cli_info "[CLI] resume subcommand invoked (no logic yet)"
    cli_warn "Command 'resume' is not yet implemented."
    cli_info "This will resume from the last successful checkpoint."
    cli_info "Requires state tracking (future phase)."
    exit 0
}

# ============================================================================
# Subcommand Dispatch
# ============================================================================
dispatch_subcommand() {
    case "$SUBCOMMAND" in
        help|"")
            do_help
            ;;
        version)
            do_version
            ;;
        config)
            do_config
            ;;
        preflight)
            do_preflight
            ;;
        run)
            do_run
            ;;
        pods)
            do_pods
            ;;
        spm)
            do_spm
            ;;
        verify)
            do_verify
            ;;
        rollback)
            do_rollback
            ;;
        resume)
            do_resume
            ;;
        *)
            cli_error "Unknown command: $SUBCOMMAND"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Parse all flags first (supports flags before subcommand)
    parse_flags "$@"
    
    # Detect subcommand from remaining args
    detect_subcommand "${REMAINING_ARGS[@]}"
    
    # Handle special cases that exit early
    if [[ "$SUBCOMMAND" == "help" ]]; then
        do_help
        exit 0
    fi
    
    if [[ "$SUBCOMMAND" == "version" ]]; then
        do_version
        exit 0
    fi
    
    # Dispatch to subcommand handler
    dispatch_subcommand
}

main "$@"
