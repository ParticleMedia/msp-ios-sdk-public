#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# MSP iOS SDK Release System - Unified Entrypoint
# ============================================================================
# Purpose: Single entrypoint for all release operations.
#          Supports config-driven releases via release.yaml.
#
# Phase 2 Step 3: Complete CLI framework implementation
# ============================================================================

set +euo pipefail  # Disabled -e to allow graceful failures

# Script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ============================================
# Unified ROOT_DIR resolution (final version)
# ============================================
if [[ -z "${ROOT_DIR:-}" ]]; then
    # First try Git repo root (most reliable)
    # Change to script directory first to ensure we're in the repo
    if command -v git >/dev/null 2>&1; then
        git_root="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [[ -n "$git_root" ]]; then
            ROOT_DIR="$git_root"
        fi
    fi

    # Fallback to walking up from SCRIPT_DIR
    if [[ -z "${ROOT_DIR:-}" ]]; then
        ROOT_DIR="$SCRIPT_DIR"
        while [[ "$ROOT_DIR" != "/" ]] && [[ "${ROOT_DIR##*/}" != "Scripts" ]]; do
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        done
        if [[ "${ROOT_DIR##*/}" == "Scripts" ]]; then
            ROOT_DIR="$(dirname "$ROOT_DIR")"
        fi
    fi
fi

export ROOT_DIR

# ============================================================================
# Load Unified Logging System (Early - before other operations)
# ============================================================================
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

# Existing release scripts (delegate to these)
MODULAR_SCRIPT="$SCRIPT_DIR/release/orchestrator/modular.sh"
COCOAPODS_SCRIPT="$SCRIPT_DIR/release/publish/pods/publish.sh"
SPM_SCRIPT="$SCRIPT_DIR/release/publish/spm/publish.sh"

# Default config file location
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/release/config/release.yaml"

# Version
readonly MSP_RELEASE_VERSION="1.2.0-phase2-step3"

# ============================================================================
# Source Release Common Library (loads UI system)
# ============================================================================
# Handle NO_ANSI flag early (before sourcing release-common.sh)
# This ensures NO_COLOR is set before logging.sh is loaded
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Source release-common.sh which loads colors.sh, ui.sh, logging.sh, and utils
if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
    # shellcheck source=Scripts/lib/release-common.sh
    source "$ROOT_DIR/Scripts/lib/release-common.sh"
else
    echo "ERROR: release-common.sh not found" >&2
    exit 1
fi

# Source git and github utilities for rollback operations
if [[ -f "$SCRIPT_DIR/release/utils/git.sh" ]]; then
    # shellcheck source=Scripts/release/utils/git.sh
    source "$SCRIPT_DIR/release/utils/git.sh" 2>/dev/null || true
fi

if [[ -f "$SCRIPT_DIR/release/utils/github.sh" ]]; then
    # shellcheck source=Scripts/release/utils/github.sh
    source "$SCRIPT_DIR/release/utils/github.sh" 2>/dev/null || true
fi

if [[ -f "$SCRIPT_DIR/release/utils/state.sh" ]]; then
    # shellcheck source=Scripts/release/utils/state.sh
    source "$SCRIPT_DIR/release/utils/state.sh" 2>/dev/null || true
fi

# Source interactive utilities for CLI mode
if [[ -f "$SCRIPT_DIR/release/interactive_utils.sh" ]]; then
    # shellcheck source=Scripts/release/interactive_utils.sh
    source "$SCRIPT_DIR/release/interactive_utils.sh" 2>/dev/null || true
fi

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
    "verify-matrix"
    "rollback"
    "resume"
    "fix-public-tag"
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
FORCE=false
INTERACTIVE=false
CONFIG_FILE=""
CLI_VERSION=""
SUBCOMMAND=""
PROFILE=""

# ============================================================================
# Logging Functions
# ============================================================================
# All logging functions are provided by release-common.sh (via logging.sh)
# log_info, log_success, log_error, log_warn, log_debug are available
# NO_ANSI is handled by release-common.sh setting NO_COLOR=1

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
                CONFIG_FILE="$2"
                shift 2
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

            --interactive)
                INTERACTIVE=true
                shift
                ;;

            --no-ansi)
                NO_ANSI=true
                shift
                ;;

            --force)
                FORCE=true
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

            --tier|--tier=*)
                # Phase B: --tier is deprecated, use --profile instead
                log_warning "--tier is deprecated in Phase B, use --profile instead"
                log_warning "  Example: --profile=production (for production mode)"
                log_warning "  Example: --profile=local-dev (for dry-run mode)"
                if [[ "$1" == "--tier" ]]; then
                    shift 2
                else
                    shift
                fi
                ;;

            --profile)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    PROFILE="$2"
                    shift 2
                else
                    log_error "--profile requires a value"
                    exit 1
                fi
                ;;

            --profile=*)
                PROFILE="${1#*=}"
                shift
                ;;

            --version|-v)
                SUBCOMMAND="version"
                shift
                ;;

            --help|-h)
                SUBCOMMAND="help"
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
        log_debug "[CLI] Override: RELEASE_VERSION=$CLI_VERSION"
    fi
    
    # Pods enabled override
    if [[ "$SKIP_PODS" == "true" ]]; then
        export PODS_ENABLED="false"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_pods_enabled "false"
        fi
        log_debug "[CLI] Override: PODS_ENABLED=false"
    elif [[ "$ONLY_PODS" == "true" ]]; then
        export PODS_ENABLED="true"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_pods_enabled "true"
        fi
        log_debug "[CLI] Override: PODS_ENABLED=true (only-pods)"
    fi
    
    # SPM enabled override
    if [[ "$SKIP_SPM" == "true" ]]; then
        export SPM_ENABLED="false"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_spm_enabled "false"
        fi
        log_debug "[CLI] Override: SPM_ENABLED=false"
    elif [[ "$ONLY_SPM" == "true" ]]; then
        export SPM_ENABLED="true"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_spm_enabled "true"
        fi
        log_debug "[CLI] Override: SPM_ENABLED=true (only-spm)"
    fi
    
    # Export other CLI flags
    export DRY_RUN="$DRY_RUN"
    export VERBOSE="$VERBOSE"
    export SKIP_PREFLIGHT="$SKIP_PREFLIGHT"
    export NO_ANSI="$NO_ANSI"
    export MSP_RELEASE_FORCE="$FORCE"

    log_debug "[CLI] Applied all CLI overrides"
}

# ============================================================================
# Load Release Configuration
# ============================================================================
# Loads YAML config file and exports environment variables for later phases.
# Implements override priority: CLI args > YAML config > built-in defaults
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
    export PODS_REMOTE_URL="$(get_config_pods_remote_url)"
    export PODS_REMOTE_PRIMARY_PRODUCT="$(get_config_pods_remote_primary_product)"
    export SPM_REMOTE_URL="$(get_config_spm_remote_url)"
    export SPM_REMOTE_PRODUCT_NAME="$(get_config_spm_remote_product_name)"
    export VERIFY_SPM_STRICT="$(get_config_verify_spm_strict)"
    
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
    resume [VERSION]  Resume a failed release (auto-detects version from state file)
    pods <VERSION>    Execute CocoaPods release only
    spm <VERSION>     Execute SPM release only
    verify <VERSION>  Verify a released version (post-release validation)
    verify-matrix     Run full verification matrix (all test cases)
    rollback          Rollback a failed release
    fix-public-tag <VERSION>  Fix public remote tag SHA mismatch

GLOBAL FLAGS:
    --config <file>       Load release configuration from YAML file
    --profile <name>      Use configuration profile (default: local-dev)
                          Available profiles:
                            - local-dev: Local development (dry-run, minimal validation)
                            - ci-test: CI testing (dry-run, full validation, JSON logs)
                            - production: Production release (publish enabled)
                            - quick-test: Quick test (no validation)
    --verbose, -V         Enable verbose output (includes config summary)
    --dry-run             Show what would be done without executing
    --no-ansi             Disable colored output
    --interactive         Enable interactive mode (version selection, confirmation prompts)
    --skip-preflight      Skip preflight validation
    --skip-pods           Skip CocoaPods release
    --skip-spm            Skip SPM release
    --only-pods           Only run CocoaPods release (implies --skip-spm)
    --only-spm            Only run SPM release (implies --skip-pods)
    --version, -v         Show version information
    --help, -h            Show this help message

OVERRIDE PRIORITY (highest to lowest):
    1. CLI flags (VERSION argument, --skip-pods, etc.)
    2. Environment variables (override profile settings)
    3. Profile settings (from --profile or default profile)
    4. Config file values (release.yaml)
    5. Built-in defaults

CONFIGURATION:
    Profile-based configuration is available via Scripts/config/release.yaml.
    All profile settings can be overridden via environment variables.
    See Scripts/config/release.yaml for full configuration options.

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

    # Run release using profile
    msp-release.sh --profile=production run 0.4.0-rc.1
    msp-release.sh --profile=local-dev run 0.4.0-rc.1

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

    # Resume failed release
    msp-release.sh resume 0.3.0-rc.7
    msp-release.sh resume              # Auto-detect version from state file

    # Interactive mode (version selection + confirmation prompts)
    msp-release.sh --interactive run

    # One-click release (default, no interaction)
    msp-release.sh run 0.4.0-rc.1

    # One-click resume (default, no confirmation)
    msp-release.sh resume 0.3.0-rc.9

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
    echo "  pods/publish.sh: $COCOAPODS_SCRIPT"
    echo "  spm/publish.sh:  $SPM_SCRIPT"
}

# ============================================================================
# Interactive Release Setup (Phase 2)
# ============================================================================
_msp_interactive_release_setup() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "MSP Release - Interactive Setup"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Step 1: Version Selection
    local version_choice
    version_choice=$(msp_prompt_menu "Select version source:" \
        "Manual input" \
        "Auto bump patch" \
        "Auto bump minor" \
        "Auto bump major" \
        "Auto pre-release (0.0.1-xxx)")
    
    local version=""
    case "$version_choice" in
        0)
            version=$(msp_prompt_text "Enter version:" "")
            ;;
        1)
            if [[ -f "$ROOT_DIR/Scripts/release/auto_version.sh" ]]; then
                version=$(bash "$ROOT_DIR/Scripts/release/auto_version.sh" "auto:patch" 2>/dev/null || echo "")
            fi
            if [[ -z "$version" ]]; then
                log_error "Failed to auto-bump patch version"
                version=$(msp_prompt_text "Enter version manually:" "")
            fi
            ;;
        2)
            if [[ -f "$ROOT_DIR/Scripts/release/auto_version.sh" ]]; then
                version=$(bash "$ROOT_DIR/Scripts/release/auto_version.sh" "auto:minor" 2>/dev/null || echo "")
            fi
            if [[ -z "$version" ]]; then
                log_error "Failed to auto-bump minor version"
                version=$(msp_prompt_text "Enter version manually:" "")
            fi
            ;;
        3)
            if [[ -f "$ROOT_DIR/Scripts/release/auto_version.sh" ]]; then
                version=$(bash "$ROOT_DIR/Scripts/release/auto_version.sh" "auto:major" 2>/dev/null || echo "")
            fi
            if [[ -z "$version" ]]; then
                log_error "Failed to auto-bump major version"
                version=$(msp_prompt_text "Enter version manually:" "")
            fi
            ;;
        4)
            version=$(msp_prompt_text "Enter pre-release version (e.g., 0.0.1-alpha):" "")
            ;;
    esac
    
    if [[ -z "$version" ]]; then
        log_error "Version is required"
        exit 1
    fi
    
    export RELEASE_VERSION="$version"
    echo ""
    
    # Step 2: Release Notes
    local notes_choice
    notes_choice=$(msp_prompt_menu "Select release notes source:" \
        "Manual input" \
        "Auto generate from git commits" \
        "Load from file NOTES.txt")
    
    local release_notes=""
    case "$notes_choice" in
        0)
            release_notes=$(msp_prompt_text "Enter release notes:" "")
            ;;
        1)
            # Auto-generate from git commits (last 10 commits)
            if command -v git >/dev/null 2>&1; then
                release_notes=$(git log --oneline -10 2>/dev/null | head -c 500 || echo "Auto-generated release notes")
            else
                release_notes="Auto-generated release notes"
            fi
            echo "Auto-generated release notes: ${release_notes:0:50}..."
            ;;
        2)
            if [[ -f "$ROOT_DIR/NOTES.txt" ]]; then
                release_notes=$(cat "$ROOT_DIR/NOTES.txt" | head -c 1000)
                echo "Loaded release notes from NOTES.txt"
            else
                log_warn "NOTES.txt not found, using manual input"
                release_notes=$(msp_prompt_text "Enter release notes:" "")
            fi
            ;;
    esac
    
    export RELEASE_NOTES="${release_notes:-No release notes provided}"
    echo ""
    
    # Step 3: Component Selection
    local component_selection
    component_selection=$(msp_prompt_checkboxes "Select components to release:" \
        "CocoaPods" \
        "SPM" \
        "XCF verify" \
        "Local verify" \
        "Remote verify" \
        "Device verify")
    
    # Parse component selection
    export MSP_PODS_ENABLED="false"
    export MSP_SPM_ENABLED="false"
    export MSP_XCF_VERIFY="false"
    export MSP_VERIFY_LOCAL="false"
    export MSP_VERIFY_REMOTE="false"
    export MSP_VERIFY_DEVICE="false"
    
    for idx in $component_selection; do
        case "$idx" in
            0) export MSP_PODS_ENABLED="true" ;;
            1) export MSP_SPM_ENABLED="true" ;;
            2) export MSP_XCF_VERIFY="true" ;;
            3) export MSP_VERIFY_LOCAL="true" ;;
            4) export MSP_VERIFY_REMOTE="true" ;;
            5) export MSP_VERIFY_DEVICE="true" ;;
        esac
    done
    
    # Phase 3: CLI mode enforcement rules
    if [[ "$MSP_SPM_ENABLED" == "true" ]]; then
        # Rule: If SPM is selected, force enable XCF verify
        if [[ "$MSP_XCF_VERIFY" != "true" ]]; then
            echo ""
            echo "${MSP_COLOR_YELLOW}⚠️  SPM release selected — automatically enabling XCF verify${MSP_COLOR_RESET}"
            export MSP_XCF_VERIFY="true"
        fi
    fi
    
    if [[ "$MSP_PODS_ENABLED" == "true" ]]; then
        # Rule: Check CocoaPods trunk session
        if command -v pod >/dev/null 2>&1; then
            local trunk_info
            trunk_info=$(pod trunk me 2>&1 || echo "")
            if [[ "$trunk_info" =~ "No session" ]] || [[ "$trunk_info" =~ "authentication" ]]; then
                echo ""
                echo "${MSP_COLOR_YELLOW}⚠️  CocoaPods trunk session may be expired. Please run 'pod trunk register' if needed.${MSP_COLOR_RESET}"
            fi
        fi
    fi
    
    if [[ "$MSP_VERIFY_DEVICE" == "true" ]]; then
        # Rule: Device verification requires iPhone connection
        echo ""
        echo "${MSP_COLOR_YELLOW}⚠️  Device verification requires a connected iPhone.${MSP_COLOR_RESET}"
    fi
    
    # Default: enable both Pods and SPM if nothing selected
    if [[ "$MSP_PODS_ENABLED" != "true" ]] && [[ "$MSP_SPM_ENABLED" != "true" ]]; then
        export MSP_PODS_ENABLED="true"
        export MSP_SPM_ENABLED="true"
        echo "No components selected, defaulting to CocoaPods + SPM"
        # Also enable XCF verify by default when SPM is enabled
        export MSP_XCF_VERIFY="true"
    fi
    
    echo ""
    
    # Step 4: Final Confirmation
    echo "═══════════════════════════════════════════════════════════════════"
    echo "Release Summary:"
    echo "  Version: $RELEASE_VERSION"
    echo "  Release Notes: ${RELEASE_NOTES:0:50}${RELEASE_NOTES:50:+...}"
    echo "  Components:"
    [[ "$MSP_PODS_ENABLED" == "true" ]] && echo "    - CocoaPods"
    [[ "$MSP_SPM_ENABLED" == "true" ]] && echo "    - SPM"
    [[ "$MSP_XCF_VERIFY" == "true" ]] && echo "    - XCF verify"
    [[ "$MSP_VERIFY_LOCAL" == "true" ]] && echo "    - Local verify"
    [[ "$MSP_VERIFY_REMOTE" == "true" ]] && echo "    - Remote verify"
    [[ "$MSP_VERIFY_DEVICE" == "true" ]] && echo "    - Device verify"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    if ! msp_prompt_yes_no "You are about to release version: $RELEASE_VERSION. Confirm?" "N"; then
        log_info "Release cancelled by user"
        exit 0
    fi
    
    echo ""
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
        log_error "Config module not available"
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
    log_section "MSP Release - Preflight"
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get version from remaining args or config (for validation)
    if [[ -n "${REMAINING_ARGS:-}" ]] && [[ ${#REMAINING_ARGS[@]} -gt 0 ]] && [[ ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        CLI_VERSION="${REMAINING_ARGS[0]}"
        if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
            set_config_version "$CLI_VERSION"
        fi
        export RELEASE_VERSION="$CLI_VERSION"
        apply_cli_overrides
    fi
    
    # Load preflight script
    local PRE_SCRIPT="$ROOT_DIR/Scripts/release/preflight/preflight.sh"
    if [[ ! -f "$PRE_SCRIPT" ]]; then
        log_error "Preflight script not found at $PRE_SCRIPT"
        return 1
    fi
    
    # shellcheck source=Scripts/release/preflight/preflight.sh
    source "$PRE_SCRIPT"
    
    # Run preflight checks
    if ! preflight_static; then
        log_error "Static preflight failed"
        return 1
    fi
    
    if ! preflight_build; then
        log_error "Build preflight failed"
        return 1
    fi
    
    log_success "All preflight checks passed"
    return 0
}

do_fix_public_tag() {
    # Fix public remote tag mismatch
    if [[ ${#REMAINING_ARGS[@]} -eq 0 ]]; then
        log_error "Usage: $0 fix-public-tag <version>"
        exit 1
    fi

    local version="${REMAINING_ARGS[0]}"

    log_info "════════════════════════════════════════════════════════════"
    log_info "  Fixing public remote tag: $version"
    log_info "════════════════════════════════════════════════════════════"

    # Check if local tag exists
    if ! git rev-parse "refs/tags/$version" >/dev/null 2>&1; then
        log_error "Local tag $version not found"
        exit 1
    fi

    local local_sha
    local_sha=$(git rev-parse "refs/tags/$version")

    log_info "本地 tag SHA: $local_sha"

    # Check public remote tag
    local public_sha
    public_sha=$(git ls-remote --tags public "refs/tags/$version" 2>/dev/null | awk '{print $1}')

    if [[ -n "$public_sha" ]]; then
        log_info "远程 tag SHA: $public_sha"

        if [[ "$local_sha" == "$public_sha" ]]; then
            log_success "✅ Tag already correct on public remote"
            exit 0
        fi

        log_warning "Tag SHA 不匹配，将强制更新..."
    else
        log_warning "Public remote 上没有找到 tag，将创建..."
    fi

    # Delete old tag
    log_info "删除 public remote 上的旧 tag..."
    git push public ":refs/tags/$version" 2>/dev/null || true

    # Push new tag
    log_info "推送正确的 tag 到 public remote..."
    local push_output
    push_output=$(git push public "refs/tags/$version" 2>&1)
    local push_exit_code=$?

    if [[ $push_exit_code -eq 0 ]]; then
        log_success "✅ Tag 推送成功"

        # Verify
        sleep 2
        local new_public_sha
        new_public_sha=$(git ls-remote --tags public "refs/tags/$version" 2>/dev/null | awk '{print $1}')

        if [[ "$new_public_sha" == "$local_sha" ]]; then
            log_success "✅ 验证成功: public remote tag 已更新"
            log_info "Tag $version 现在指向正确的 commit: $local_sha"
        else
            log_error "❌ 验证失败: tag SHA 仍不匹配"
            log_error "期望: $local_sha"
            log_error "实际: $new_public_sha"
            exit 1
        fi
    else
        log_error "❌ Tag 推送失败"
        log_error ""
        log_error "推送输出:"
        echo "$push_output"
        log_error ""
        
        if echo "$push_output" | grep -qi "push protection"; then
            log_error "GitHub Push Protection 阻止了推送"
            log_error "请访问 GitHub Web 界面手动允许推送"
            log_error "检查推送输出中的 URL 链接"
        fi
        
        exit 1
    fi
}

do_run() {
    # Record author email for Slack notifications
    AUTHOR_EMAIL="$(git config user.email 2>/dev/null || echo "")"
    export MSP_AUTHOR_EMAIL="$AUTHOR_EMAIL"
    
    # Initialize logging system for this release run
    local version="${REMAINING_ARGS[0]:-unknown}"
    local dry_run="${DRY_RUN:-true}"
    local mode_label="dryrun"
    if [[ "$dry_run" == "false" ]]; then
        mode_label="production"
    fi
    if command -v log::info &>/dev/null; then
        # Generate unique session ID for this release
        export MSP_SESSION_ID="${MSP_SESSION_ID:-$(date +%Y%m%d-%H%M%S)-$$}"

        export MSP_LOG_FILE="/tmp/msp-release-${version}-${mode_label}-${MSP_SESSION_ID}.log"
        export MSP_METRICS_FILE="/tmp/msp-release-${version}-${mode_label}-${MSP_SESSION_ID}-metrics.json"

        log::info "MSP" "Starting MSP iOS SDK Release"
        log::info "MSP" "Version: $version"
        log::info "MSP" "Mode: $mode_label (DRY_RUN=$dry_run)"
        log::info "MSP" "Session ID: $MSP_SESSION_ID"
        log::info "MSP" "Log file: $MSP_LOG_FILE"
        log::info "MSP" "Metrics file: $MSP_METRICS_FILE"
        metrics::start "msp_release_total"
    else
        log_info "[CLI] run subcommand invoked"
    fi
    
    # Scheme A: always reset state for a new 'run' invocation
    local state_file="${ROOT_DIR}/.msp-release-state.json"
    if [[ -f "$state_file" ]]; then
        if command -v log::info &>/dev/null; then
            log::info "MSP" "Resetting state file for fresh run"
        else
            log_info "Resetting state file for fresh run"
        fi
        rm -f "$state_file"
    fi
    
    # Ensure MSP_RESUME_MODE is unset for normal runs
    unset MSP_RESUME_MODE
    
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
    
    # Interactive mode: only when explicitly requested via --interactive flag
    # Requires: CLI mode + version not set + terminal stdin + --interactive flag
    if [[ "${MSP_RELEASE_MODE:-cli}" == "cli" ]] && \
       [[ -z "${RELEASE_VERSION:-}" ]] && \
       [[ -t 0 ]] && \
       [[ "$INTERACTIVE" == "true" ]]; then
        _msp_interactive_release_setup
    fi
    
    # Apply interactive component selections to environment
    if [[ "${MSP_PODS_ENABLED:-}" == "true" ]]; then
        export PODS_ENABLED="true"
    elif [[ "${MSP_PODS_ENABLED:-}" == "false" ]]; then
        export PODS_ENABLED="false"
    fi
    
    if [[ "${MSP_SPM_ENABLED:-}" == "true" ]]; then
        export SPM_ENABLED="true"
    elif [[ "${MSP_SPM_ENABLED:-}" == "false" ]]; then
        export SPM_ENABLED="false"
    fi
    
    # Check if version is set (after interactive setup)
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        log_error "VERSION is required for 'run' command"
        log_info "Usage: msp-release.sh run <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh run --config <file>  (with version in config)"
        exit 1
    fi
    
    # Run preflight checks (unless skipped)
    if [[ "${SKIP_PREFLIGHT:-false}" != "true" ]]; then
        log_info "Running preflight checks (use --skip-preflight to disable)"
        
        local PRE_SCRIPT="$ROOT_DIR/Scripts/release/preflight/preflight.sh"
        if [[ ! -f "$PRE_SCRIPT" ]]; then
            log_error "Preflight script not found at $PRE_SCRIPT"
            return 1
        fi
        
        # shellcheck source=Scripts/release/preflight/preflight.sh
        source "$PRE_SCRIPT"
        
        if ! preflight_static; then
            log_error "Static preflight failed. Aborting release"
            # Send failure notification
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Static preflight checks failed (git, branch, or version validation)" "Preflight Static"
            fi
            return 1
        fi
        
        if ! preflight_build; then
            log_error "Build preflight failed. Aborting release"
            # Send failure notification
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Build preflight failed (XCFramework build or round-trip test)" "Preflight Build"
            fi
            return 1
        fi
        
        log_success "Preflight checks passed"
    else
        log_warn "Skipping preflight due to --skip-preflight flag"
    fi
    
    # Release mode: CLI
    # ============================================================================
    # DEBUG: Tier Detection
    # ============================================================================
    echo "[DEBUG] ========================================" >&2
    echo "[DEBUG] Tier Detection at Script Start" >&2
    echo "[DEBUG] ========================================" >&2
    echo "[DEBUG] DRY_RUN (env): ${DRY_RUN:-unset}" >&2
    echo "[DEBUG] Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')" >&2
    echo "[DEBUG] ========================================" >&2

    # Set DRY_RUN default (Phase B)
    if [ -z "${DRY_RUN:-}" ]; then
      DRY_RUN="true"
      log_info "[MODE] DRY_RUN not set; defaulting to dry-run mode (true)"
    fi
    export DRY_RUN
    local mode_label="dry-run"
    if [[ "${DRY_RUN}" == "false" ]]; then
      mode_label="production"
    fi
    log_info "[MODE] Running in ${mode_label} mode (DRY_RUN=${DRY_RUN})"
    export MSP_RELEASE_MODE="${MSP_RELEASE_MODE:-cli}"
    echo "[MSP][CLI] Release mode: ${MSP_RELEASE_MODE}"
    
    # For now, delegate to modular.sh (backward compatibility)
    if command -v log::info &>/dev/null; then
        log::info "MSP" "Delegating to: $MODULAR_SCRIPT"
        log::info "MSP" "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    else
        log_info "Delegating to: $MODULAR_SCRIPT"
        log_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    fi
    
    bash "$MODULAR_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
    local result=$?
    
    # End timing and generate reports
    if command -v metrics::end &>/dev/null; then
        metrics::end "msp_release_total"
        metrics::report
        metrics::save
        
        # Generate analytics summary
        if [[ -f "$ROOT_DIR/Scripts/release/utils/analytics.sh" ]]; then
            source "$ROOT_DIR/Scripts/release/utils/analytics.sh" 2>/dev/null || true
            if command -v analytics::summary &>/dev/null; then
                analytics::summary "$MSP_METRICS_FILE" "$MSP_LOG_FILE"
            fi
        fi
        
        if command -v log::success &>/dev/null; then
            log::success "MSP" "Release completed!"
            log::info "MSP" "Full logs: $MSP_LOG_FILE"
            log::info "MSP" "Metrics: $MSP_METRICS_FILE"
        fi
    fi
    
    return $result
}

do_pods() {
    log_info "[CLI] pods subcommand invoked"
    
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
        log_error "VERSION is required for 'pods' command"
        log_info "Usage: msp-release.sh pods <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh pods --config <file>  (with version in config)"
        exit 1
    fi
    
    # For now, delegate to cocoapods.sh (backward compatibility)
    log_info "Delegating to: $COCOAPODS_SCRIPT"
    log_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    exec "$COCOAPODS_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

do_spm() {
    log_info "[CLI] spm subcommand invoked"
    
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
        log_error "VERSION is required for 'spm' command"
        log_info "Usage: msp-release.sh spm <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh spm --config <file>  (with version in config)"
        exit 1
    fi
    
    # For now, delegate to spm.sh (backward compatibility)
    log_info "Delegating to: $SPM_SCRIPT"
    log_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    exec "$SPM_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}
}

do_verify() {
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get version from remaining args or config
    local version="${RELEASE_VERSION:-}"
    if [[ -n "${REMAINING_ARGS:-}" ]] && [[ ${#REMAINING_ARGS[@]} -gt 0 ]] && [[ -n "${REMAINING_ARGS[0]:-}" ]] && [[ ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        version="${REMAINING_ARGS[0]}"
        export RELEASE_VERSION="$version"
        apply_cli_overrides
    fi
    
    if [[ -z "$version" ]]; then
        log_error "Missing version for verify"
        log_info "Usage: msp-release.sh verify <VERSION> [OPTIONS]"
        log_info "   or: msp-release.sh verify --config <file>  (with version in config)"
        exit 1
    fi
    
    # Load verify script
    local VERIFY_SCRIPT="$ROOT_DIR/Scripts/release/verify/verify.sh"
    if [[ ! -f "$VERIFY_SCRIPT" ]]; then
        log_error "Verify script not found at $VERIFY_SCRIPT"
        return 1
    fi
    
    # shellcheck source=Scripts/release/verify/verify.sh
    source "$VERIFY_SCRIPT"
    
    log_title "Verifying Remote Release (Pods + SPM placeholder)"
    
    if ! verify_main "$version"; then
        log_error "Remote verification failed"
        return 1
    fi
    
    return 0
}

do_verify_matrix() {
    log_title "MSP Release Verification Matrix"
    
    # Load config (applies CLI overrides)
    load_release_config
    
    # Get matrix script path
    local MATRIX_SCRIPT="$ROOT_DIR/Scripts/release/verify-matrix/matrix.sh"
    if [[ ! -f "$MATRIX_SCRIPT" ]]; then
        log_error "Verification matrix script not found at $MATRIX_SCRIPT"
        return 1
    fi
    
    # Pass through environment variables
    export DRY_RUN="${DRY_RUN:-false}"
    export VERBOSE="${VERBOSE:-false}"
    export NO_ANSI="${NO_ANSI:-false}"
    
    # Run matrix script
    if bash "$MATRIX_SCRIPT"; then
        log_success "Verification matrix completed successfully"
        return 0
    else
        log_error "Verification matrix failed"
        return 1
    fi
}

do_rollback() {
    log_title "MSP Release - Rollback Plan"
    
    # Parse rollback-specific flags
    MSP_ROLLBACK_FORCE=0
    
    # Initialize REMAINING_ARGS if not set
    if [[ -z "${REMAINING_ARGS:-}" ]]; then
        REMAINING_ARGS=()
    fi
    
    local remaining_rollback_args=()
    for arg in "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"; do
        case "$arg" in
            --force)
                MSP_ROLLBACK_FORCE=1
                ;;
            --no-ansi)
                NO_ANSI=true
                export NO_ANSI
                ;;
            *)
                remaining_rollback_args+=("$arg")
                ;;
        esac
    done
    
    export MSP_ROLLBACK_FORCE
    
    # Delegate to rollback handler
    run_msp_rollback
    exit $?
}

# Rollback handler function
run_msp_rollback() {
    # Determine repo root and state file
    local state_file="${ROOT_DIR}/.msp-release-state.json"
    
    if [[ ! -f "$state_file" ]]; then
        log_error "No .msp-release-state.json found. Nothing to roll back."
        log_info "State file not found: $state_file"
        log_info "Please run 'msp-release.sh run <VERSION>' first to start a release."
        return 1
    fi
    
    # Use jq (if available) to read the state
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required to inspect rollback state."
        log_info "Please install jq to use the rollback command."
        return 1
    fi
    
    # Extract relevant fields
    local version release_branch tag_created tag_name branch_pushed gh_release_created
    
    version="$(jq -r '.version // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    release_branch="$(jq -r '.release_branch // "unknown"' "$state_file" 2>/dev/null || echo "unknown")"
    tag_created="$(jq -r '.git.tag_created // false' "$state_file" 2>/dev/null || echo "false")"
    tag_name="$(jq -r '.git.tag_name // empty' "$state_file" 2>/dev/null || echo "")"
    branch_pushed="$(jq -r '.git.release_branch_pushed // false' "$state_file" 2>/dev/null || echo "false")"
    gh_release_created="$(jq -r '.git.github_release_created // false' "$state_file" 2>/dev/null || echo "false")"
    
    # Print a clear rollback plan
    log_section "MSP Rollback Plan"
    ui_kv "Version" "${version}"
    ui_kv "Release branch" "${release_branch}"
    ui_kv "Git tag" "${tag_name:-<none>}"
    echo ""
    
    log_section "Planned Actions"
    
    if [[ "$tag_created" == "true" ]]; then
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            log_info "- Would delete local git tag: ${tag_name}"
            log_info "- Would delete remote git tag: ${tag_name}"
        else
            log_info "- Git tag was created but tag name is not recorded"
            log_info "- Would attempt to identify and delete tags for version: ${version}"
        fi
    else
        log_info "- No git tag recorded as created"
    fi
    
    echo ""
    
    if [[ "$branch_pushed" == "true" ]]; then
        if [[ "$release_branch" != "unknown" && "$release_branch" != "null" && -n "$release_branch" ]]; then
            log_info "- Would delete remote release branch: ${release_branch}"
        else
            log_info "- Release branch was pushed but branch name is not recorded"
        fi
    else
        log_info "- No release branch recorded as pushed"
    fi
    
    echo ""
    
    if [[ "$gh_release_created" == "true" ]]; then
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            log_info "- Would delete GitHub Release associated with tag: ${tag_name}"
        elif [[ "$version" != "unknown" ]]; then
            log_info "- Would delete GitHub Release associated with version: ${version}"
        else
            log_info "- GitHub Release was created but tag/version is not recorded"
        fi
    else
        log_info "- No GitHub Release recorded as created"
    fi
    
    echo ""
    log_section "CocoaPods Considerations"
    log_info "- CocoaPods trunk does not support automatic unpublish"
    log_info "- Manual remediation may be required (e.g., publish a new version)"
    echo ""
    
    # If --force is not set, just print the plan and exit
    if [[ "${MSP_ROLLBACK_FORCE:-0}" != "1" ]]; then
        log_info "No changes have been made. Re-run with --force to execute destructive rollback operations"
        return 0
    fi
    
    # --force is set: ask for confirmation and execute
    log_warn "Destructive rollback operations WILL be executed as described above"
    log_warn "This includes deleting git tags/branches and GitHub Releases"
    log_info "Press ENTER to continue, or Ctrl+C to abort"
    echo ""
    
    # Confirmation (Scheme A)
    # Use read -r to wait for ENTER; in non-interactive environments,
    # users can pipe a newline: `printf '\n' | msp-release.sh rollback --force`
    read -r _
    
    # Execute rollback actions
    if _msp_execute_rollback_actions \
        "$version" \
        "$release_branch" \
        "$tag_created" \
        "$tag_name" \
        "$branch_pushed" \
        "$gh_release_created"; then
        
        # On success, reset git flags in the state
        if command -v msp_state_reset_git_flags &>/dev/null; then
            msp_state_reset_git_flags
        fi
        
        log_section "Rollback completed successfully"
        return 0
    else
        log_section "Rollback completed with errors"
        # Optionally still call msp_state_reset_git_flags() if some actions succeeded.
        # For now, we leave the git flags as-is so users can see that not all actions were completed.
        return 1
    fi
}

# Private helper to execute rollback actions
_msp_execute_rollback_actions() {
    local version="$1"
    local release_branch="$2"
    local tag_created="$3"
    local tag_name="$4"
    local branch_pushed="$5"
    local gh_release_created="$6"
    
    local any_error=0
    
    log_section "Executing Destructive Rollback Actions"
    
    # 1) Delete git tag (local + remote) if recorded as created
    if [[ "$tag_created" == "true" ]]; then
        if [[ -z "$tag_name" || "$tag_name" == "null" || "$tag_name" == "" ]]; then
            log_warn "State indicates tag_created=true but tag_name is empty. Skipping tag deletion"
        else
            log_info "Deleting git tag (local + remote): ${tag_name}"
            if command -v msp_git_delete_tag &>/dev/null; then
                if ! msp_git_delete_tag "$tag_name"; then
                    log_error "Failed to delete git tag ${tag_name}"
                    any_error=1
                fi
            else
                log_error "msp_git_delete_tag function not available"
                any_error=1
            fi
        fi
    else
        log_info "No git tag recorded as created. Skipping git tag deletion"
    fi
    
    echo ""
    
    # 2) Delete remote release branch if recorded as pushed
    if [[ "$branch_pushed" == "true" ]]; then
        if [[ -z "$release_branch" || "$release_branch" == "unknown" || "$release_branch" == "null" ]]; then
            log_warn "State indicates release_branch_pushed=true but release_branch is unknown. Skipping remote branch deletion"
        else
            log_info "Deleting remote release branch: ${release_branch}"
            if command -v msp_git_delete_remote_branch &>/dev/null; then
                if ! msp_git_delete_remote_branch "$release_branch"; then
                    log_error "Failed to delete remote release branch ${release_branch}"
                    any_error=1
                fi
            else
                log_error "msp_git_delete_remote_branch function not available"
                any_error=1
            fi
        fi
    else
        log_info "No release branch recorded as pushed. Skipping remote branch deletion"
    fi
    
    echo ""
    
    # 3) Delete GitHub Release if recorded as created
    if [[ "$gh_release_created" == "true" ]]; then
        local release_target=""
        if [[ -n "$tag_name" && "$tag_name" != "null" && "$tag_name" != "" ]]; then
            release_target="$tag_name"
        elif [[ "$version" != "unknown" && "$version" != "null" && -n "$version" ]]; then
            release_target="$version"
        fi
        
        if [[ -z "$release_target" ]]; then
            log_warn "State indicates github_release_created=true but tag_name/version is empty. Skipping GitHub Release deletion"
        else
            log_info "Deleting GitHub Release: ${release_target}"
            if command -v github_delete_release &>/dev/null; then
                if ! github_delete_release "$release_target"; then
                    log_error "Failed to delete GitHub Release ${release_target}"
                    any_error=1
                fi
            else
                log_error "github_delete_release function not available"
                any_error=1
            fi
        fi
    else
        log_info "No GitHub Release recorded as created. Skipping GitHub Release deletion"
    fi
    
    echo ""
    
    # 4) CocoaPods considerations (no automatic unpublish)
    log_section "CocoaPods Considerations"
    log_info "- CocoaPods trunk does not support automatic unpublish"
    log_info "- If a broken version has been published, the recommended remediation is:"
    log_info "    1) Bump a new version (e.g., patch/minor)"
    log_info "    2) Release the new version with the fixes"
    log_info "    3) Communicate deprecation of the problematic version if necessary"
    echo ""
    
    if [[ $any_error -ne 0 ]]; then
        log_warn "Rollback actions completed with errors. See messages above"
        return 1
    fi
    
    log_success "All destructive rollback actions completed successfully"
    return 0
}

do_resume() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "🔄 MSP Release Resume"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if state file exists
    local state_file="${ROOT_DIR}/.msp-release-state.json"
    if [[ ! -f "$state_file" ]]; then
        log_error "❌ No previous release run found. Cannot resume."
        log_info "State file not found: $state_file"
        log_info "Please run 'msp-release.sh run <VERSION>' first to start a release."
        exit 1
    fi
    
    # Auto-detect version from state file if not provided
    # Get version from REMAINING_ARGS (passed from CLI) or state file
    local version=""
    if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
        version="${REMAINING_ARGS[0]}"
    fi
    
    if [[ -z "$version" ]]; then
        if command -v jq >/dev/null 2>&1; then
            version=$(jq -r '.version // empty' "$state_file" 2>/dev/null || echo "")
            if [[ -n "$version" && "$version" != "unknown" ]]; then
                log_info "📝 Auto-detected version from state file: $version"
            fi
        fi
    fi
    
    # Verify version is set
    if [[ -z "$version" ]]; then
        log_error "❌ No version specified and no state file found"
        log_error ""
        log_error "Usage: $0 resume [VERSION]"
        log_error ""
        log_error "Examples:"
        log_error "  $0 resume 0.3.0-rc.7"
        log_error "  $0 resume              # Auto-detect from state file"
        return 1
    fi
    
    # Load release-common for POD_RELEASE_ORDER
    if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
        source "$ROOT_DIR/Scripts/lib/release-common.sh"
    else
        log_error "❌ Cannot load Scripts/lib/release-common.sh"
        return 1
    fi
    
    # Load state utilities
    if [[ -f "$ROOT_DIR/Scripts/release/utils/state.sh" ]]; then
        source "$ROOT_DIR/Scripts/release/utils/state.sh"
    fi
    
    # ============================================================================
    # CRITICAL FIX: Resume 模式同步 GitHub Release 状态
    # ============================================================================
    # Why: Resume 时，本地状态可能与 GitHub Release 不一致：
    #   - 本地 zip 可能是旧的
    #   - Podspec 可能使用了旧的 checksum
    #   - GitHub Release zip 可能被重新上传过
    #
    # Solution: 从 GitHub Release 下载 zip，强制同步本地状态
    #
    # Benefits:
    #   - 本地 zip 和 GitHub Release zip 完全一致
    #   - Podspec 使用正确的 checksum（从 GitHub Release）
    #   - Task 2 和 Task 3 验证都通过
    #   - "GitHub Release is single source of truth"
    # ============================================================================
    
    sync_from_github_release() {
        local version="$1"
        
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "🔄 Resume Mode: Syncing state from GitHub Release"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info ""
        log_info "Version: $version"
        log_info "Reason: Ensure local state matches GitHub Release (source of truth)"
        log_info ""
        
        # Step 1: Check if GitHub Release exists
        if ! gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" &>/dev/null; then
            log_warning "GitHub Release $version not found, skipping sync"
            log_warning "This is expected if this is the first run (not a resume)"
            log_info ""
            return 0
        fi
        
        log_success "✅ GitHub Release $version exists"
        log_info ""
        
        # Step 2: Get list of published pods from GitHub Release
        log_info "Step 1: Fetching assets from GitHub Release..."
        local assets
        assets=$(gh release view "$version" --repo "ParticleMedia/msp-ios-sdk-public" --json assets --jq '.assets[].name' 2>/dev/null || echo "")
        
        if [[ -z "$assets" ]]; then
            log_warning "No assets found in GitHub Release, skipping sync"
            log_info ""
            return 0
        fi
        
        local asset_count=$(echo "$assets" | grep -c ".zip$" || echo "0")
        log_info "Found $asset_count zip file(s) in GitHub Release"
        log_info ""
        
        # Step 3: Download zips from GitHub Release
        log_info "Step 2: Downloading zips from GitHub Release..."
        log_info ""
        
        local download_count=0
        local skip_count=0
        local error_count=0
        
        # Ensure Build/Zips directory exists
        mkdir -p "$ROOT_DIR/Build/Zips"
        
        # Process each zip file
        while IFS= read -r asset_name; do
            if [[ ! "$asset_name" =~ \.zip$ ]]; then
                continue
            fi
            
            local pod_name="${asset_name%-${version}.zip}"
            local local_zip="$ROOT_DIR/Build/Zips/$asset_name"
            local download_url="https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/${version}/${asset_name}"
            
            log_info "  📦 Processing: $asset_name"
            
            # Download with retry mechanism
            local temp_zip="/tmp/resume-sync-${asset_name}-$$.zip"
            local download_success=false
            local github_checksum=""
            local max_retries=3
            local retry_delay=5

            for ((retry=1; retry<=max_retries; retry++)); do
                if [[ $retry -gt 1 ]]; then
                    log_info "     Retrying download (attempt $retry/$max_retries)..."
                    sleep $retry_delay
                fi

                # Download with timeout (60 seconds)
                if timeout 60 curl -L -f -s -o "$temp_zip" "$download_url" 2>/dev/null; then
                    local file_size=$(stat -f%z "$temp_zip" 2>/dev/null || stat -c%s "$temp_zip" 2>/dev/null || echo "0")

                    if [[ $file_size -gt 0 ]]; then
                        github_checksum=$(shasum -a 256 "$temp_zip" 2>/dev/null | awk '{print $1}')

                        if [[ -n "$github_checksum" && ${#github_checksum} -eq 64 ]]; then
                            download_success=true
                            break
                        else
                            log_warning "     ⚠️  Downloaded file but checksum calculation failed, retrying..."
                            rm -f "$temp_zip"
                        fi
                    else
                        log_warning "     ⚠️  Downloaded file is empty (0 bytes), retrying..."
                        rm -f "$temp_zip"
                    fi
                else
                    if [[ $retry -lt $max_retries ]]; then
                        log_warning "     ⚠️  Download failed (attempt $retry/$max_retries), will retry..."
                    fi
                fi
            done

            if [[ "$download_success" == "true" ]]; then
                
                # Check if local zip exists and matches
                if [[ -f "$local_zip" ]]; then
                    local local_checksum=$(shasum -a 256 "$local_zip" 2>/dev/null | awk '{print $1}')
                    
                    if [[ "$local_checksum" == "$github_checksum" ]]; then
                        log_info "     ✅ Local zip already matches GitHub Release"
                        log_info "        Checksum: $github_checksum"
                        rm -f "$temp_zip"
                        ((skip_count++))
                        continue
                    else
                        log_warning "     ⚠️  Local zip checksum differs from GitHub Release"
                        log_info "        Local:  $local_checksum"
                        log_info "        GitHub: $github_checksum"
                        log_info "        → Replacing with GitHub Release version"
                    fi
                else
                    log_info "     ℹ️  Local zip not found, downloading from GitHub Release"
                fi
                
                # Replace local zip with GitHub Release version
                mv "$temp_zip" "$local_zip"
                log_success "     ✅ Downloaded and replaced: $asset_name"
                log_info "        Checksum: $github_checksum"
                ((download_count++))
            else
                log_error "     ❌ Failed to download from GitHub Release after $max_retries attempts"
                log_error "        URL: $download_url"
                log_error "        Possible causes:"
                log_error "          1. Network connectivity issues"
                log_error "          2. GitHub CDN temporarily unavailable"
                log_error "          3. File does not exist in GitHub Release"
                rm -f "$temp_zip"
                ((error_count++))
            fi
            
            log_info ""
        done <<< "$assets"
        
        # Step 4: Summary
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "📊 Sync Summary"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Total zips:     $asset_count"
        log_info "Downloaded:     $download_count"
        log_info "Already synced: $skip_count"
        log_info "Errors:         $error_count"
        log_info ""
        
        if [[ $error_count -gt 0 ]]; then
            log_warning "⚠️  Some zips failed to sync, but continuing..."
            log_warning "This may cause checksum mismatches later"
        else
            log_success "✅ All zips synced from GitHub Release"
        fi
        
        # Step 5: Delete old podspecs (will be regenerated)
        log_info ""
        log_info "Step 3: Removing old podspecs (will be regenerated)..."
        
        local podspec_dir="$ROOT_DIR/Build/ReleasePodspecs"
        if [[ -d "$podspec_dir" ]]; then
            local podspec_count=$(ls -1 "$podspec_dir"/*.podspec 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$podspec_count" -gt 0 ]]; then
                log_info "Removing $podspec_count existing podspec(s)..."
                rm -f "$podspec_dir"/*.podspec
                log_success "✅ Removed $podspec_count podspec(s)"
            else
                log_info "No existing podspecs found"
            fi
        else
            log_info "Podspec directory does not exist yet"
        fi
        
        log_info ""
        log_success "✅ Sync complete: local state matches GitHub Release"
        log_info "   - Local zips updated from GitHub Release"
        log_info "   - Old podspecs removed (will be regenerated with correct checksums)"
        log_info ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info ""
    }
    
    # Call sync function after version is determined
    if [[ -n "$version" ]]; then
        sync_from_github_release "$version"
    fi
    
    # Display resume summary
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "📋 Resume Summary for $version"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Display pod status
    local has_pending=false
    local has_failed=false
    
    for pod in "${POD_RELEASE_ORDER[@]}"; do
        local status="unknown"
        if command -v msp_state_get_pod_status &>/dev/null; then
            status=$(msp_state_get_pod_status "$pod")
        fi
        
        case "$status" in
            "published")
                log_success "  ✅ $pod - Published"
                ;;
            "failed")
                log_error "  ❌ $pod - Failed (will retry)"
                has_failed=true
                ;;
            "inconsistent")
                log_warning "  ⚠️  $pod - Inconsistent (will verify)"
                has_pending=true
                ;;
            "pending"|"unknown")
                log_info "  ⏳ $pod - Pending"
                has_pending=true
                ;;
            *)
                log_info "  ❓ $pod - $status"
                has_pending=true
                ;;
        esac
    done
    
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if there's anything to do
    if [[ "$has_pending" == "false" ]] && [[ "$has_failed" == "false" ]]; then
        log_success "✅ All pods are already published!"
        log_info ""
        log_info "No action needed. Release $version is complete."
        return 0
    fi
    
    # Confirm resume only when --interactive flag is set
    if [[ -t 0 ]] && [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        read -p "Continue with resume? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Resume cancelled by user"
            return 0
        fi
    fi
    
    echo ""
    log_info "🔄 Resuming release for $version..."
    echo ""
    
    # Increment resume count
    if command -v msp_state_increment_resume_count &>/dev/null; then
        msp_state_increment_resume_count
    fi
    
    # Set resume mode flag and version
    # Note: Use "1" (not "true") to match checks in other scripts (preflight.sh, verify.sh, etc.)
    export MSP_RESUME_MODE="1"
    export RELEASE_VERSION="$version"
    
    # Resume allows existing release (resume is for retrying failed releases)
    # Release might be in draft or published state - both are acceptable
    export MSP_ALLOW_EXISTING_RELEASE=true
    
    # Resume is non-interactive by design (auto-retry without user confirmation)
    # Explicitly set to prevent --interactive flag or profile settings from blocking
    # Even if user passes --interactive, resume should not require manual confirmation
    export INTERACTIVE=false
    
    # Load config (applies CLI overrides, but version should come from state)
    load_release_config
    
    # If version is still not set, try to get it from remaining args or config
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        if [[ ${#REMAINING_ARGS[@]} -gt 0 && ! "${REMAINING_ARGS[0]}" =~ ^- ]]; then
            CLI_VERSION="${REMAINING_ARGS[0]}"
            REMAINING_ARGS=("${REMAINING_ARGS[@]:1}")
            if [[ "$CONFIG_MODULE_LOADED" == "true" ]]; then
                set_config_version "$CLI_VERSION"
            fi
        fi
        
        if [[ -n "$CLI_VERSION" ]]; then
            export RELEASE_VERSION="$CLI_VERSION"
            apply_cli_overrides
        fi
    fi
    
    # Check if version is set
    if [[ -z "${RELEASE_VERSION:-}" ]]; then
        log_error "VERSION is required for 'resume' command"
        log_info "Usage: msp-release.sh resume [VERSION] [OPTIONS]"
        log_info "   or: msp-release.sh resume --config <file>  (with version in config)"
        log_info "Note: Version will be read from state file if not provided"
        exit 1
    fi
    
    # Run preflight checks (unless skipped) - will skip if already successful in resume mode
    if [[ "${SKIP_PREFLIGHT:-false}" != "true" ]]; then
        log_info "Running preflight checks (will skip if already successful)"
        
        local PRE_SCRIPT="$ROOT_DIR/Scripts/release/preflight/preflight.sh"
        if [[ ! -f "$PRE_SCRIPT" ]]; then
            log_error "Preflight script not found at $PRE_SCRIPT"
            return 1
        fi
        
        # shellcheck source=Scripts/release/preflight/preflight.sh
        source "$PRE_SCRIPT"
        
        if ! preflight_static; then
            log_error "Static preflight failed. Aborting resume"
            # Send failure notification
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Static preflight checks failed (git, branch, or version validation)" "Preflight Static"
            fi
            return 1
        fi
        
        if ! preflight_build; then
            log_error "Build preflight failed. Aborting resume"
            # Send failure notification
            if command -v notify_release_failure &>/dev/null; then
                notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Build preflight failed (XCFramework build or round-trip test)" "Preflight Build"
            fi
            return 1
        fi
        
        log_success "Preflight checks passed"
    else
        log_warn "Skipping preflight due to --skip-preflight flag"
    fi
    
    # Delegate to modular.sh (same as run, but with MSP_RESUME_MODE=1)
    log_info "Delegating to: $MODULAR_SCRIPT"
    log_info "Arguments: $RELEASE_VERSION ${REMAINING_ARGS[*]:-}"
    
    if ! bash "$MODULAR_SCRIPT" "$RELEASE_VERSION" ${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}; then
        local exit_code=$?
        log_error "Resume failed with exit code: $exit_code"
        # Send failure notification
        if command -v notify_release_failure &>/dev/null; then
            notify_release_failure "MSP iOS SDK" "$RELEASE_VERSION" "Release execution failed (pods publish or verification)" "Resume Execution"
        fi
        return $exit_code
    fi
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
        verify-matrix)
            do_verify_matrix
            ;;
        rollback)
            do_rollback
            ;;
        resume)
            do_resume
            ;;
        fix-public-tag)
            do_fix_public_tag
            ;;
        *)
            log_error "Unknown command: $SUBCOMMAND"
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
    # Capture original CLI arguments for state tracking (before any parsing)
    MSP_RELEASE_ORIGINAL_ARGS="$*"
    export MSP_RELEASE_ORIGINAL_ARGS
    
    # Initialize REMAINING_ARGS to avoid unbound variable errors
    REMAINING_ARGS=()
    
    # Parse all flags first (supports flags before subcommand)
    parse_flags "$@"
    
    # Load configuration from profile (if config loader is available)
    # Use default profile if not specified
    PROFILE="${PROFILE:-local-dev}"
    if [[ -f "$ROOT_DIR/Scripts/lib/config_loader.sh" ]]; then
        # shellcheck source=Scripts/lib/config_loader.sh
        source "$ROOT_DIR/Scripts/lib/config_loader.sh" 2>/dev/null || true
        if command -v load_config &>/dev/null; then
            load_config "$PROFILE" || true
            if command -v display_config &>/dev/null && [[ "$VERBOSE" == "true" ]]; then
                display_config
            fi
        fi
    fi
    
    # Detect subcommand from remaining args
    detect_subcommand "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    
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

