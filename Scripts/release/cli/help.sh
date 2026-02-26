#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Help Module
# ============================================================================
# Purpose: Provides help text and version display for the release CLI
# Usage:   source Scripts/release/cli/help.sh
#          msp_show_help
#          msp_show_version
#
# Dependencies:
#   - MSP_RELEASE_VERSION (set by msp-release.sh)
#   - CONFIG_MODULE_LOADED (set by msp-release.sh)
#   - DEFAULT_CONFIG_FILE (set by msp-release.sh)
#   - MODULAR_SCRIPT, COCOAPODS_SCRIPT, SPM_SCRIPT (set by msp-release.sh)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_HELP_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_HELP_SOURCED=1

# ============================================================================
# Help Display
# ============================================================================
# @description Displays the unified help message for the CLI
# @return Echoes help text to stdout
msp_show_help() {
    cat << 'EOF'
MSP iOS SDK Release System

USAGE:
    msp-release.sh [GLOBAL_FLAGS] <COMMAND> [COMMAND_ARGS]

COMMANDS:
    help              Show this help message
    version           Show CLI version information
    config            Print effective configuration (merged CLI > config > defaults)
    env [--show]      Print environment variables
                      - Default: Shell export format for eval "$(msp-release.sh env)"
                      - --show: Human-readable format for debugging
    preflight         Validate environment before release
    run <VERSION>     Execute full release (CocoaPods + SPM)
    resume [VERSION]  Resume a failed release (auto-detects version from state file)
    pods <VERSION>    Execute CocoaPods release only
    spm <VERSION>     Execute SPM release only
    verify <VERSION>  Verify a released version (post-release validation)
    verify-matrix     Run full verification matrix (all test cases)
    rollback          Rollback a failed release
    fix-public-tag <VERSION>  Fix public remote tag SHA mismatch
    create-github-releases <VERSION>  Create/verify GitHub releases for all binary pods

GLOBAL FLAGS:
    --config <file>       Load release configuration from YAML file
    --profile <name>      Use configuration profile (default: local-dev)
                          Available profiles:
                            - local-dev: Local development (dry-run, simple mode)
                            - quick-test: Quick test (dry-run, no validation)
                            - production: Production release (publish enabled, auto full mode)
    --verbose, -V         Enable verbose output (includes config summary)
    --dry-run             Show what would be done without executing
    --full                Run full release mode (includes verification phase)
                          Auto-enabled for --profile=production
    --base-branch <branch>  Base branch for release (overrides config and env var)
    --release-notes <text>  Set release notes for GitHub release (FR-016)
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
    msp-release.sh run --config Scripts/config/release.yaml

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

    # Full release (includes verification phase)
    msp-release.sh run 0.0.3 --full
    msp-release.sh --full run 0.0.3          # Flag can be before or after subcommand

    # Release with notes (FR-016)
    msp-release.sh run 0.0.3 --release-notes "Bug fixes and performance improvements"

    # Resume failed release
    msp-release.sh resume 0.3.0-rc.7
    msp-release.sh resume              # Auto-detect version from state file

    # Run release (fully automated, no interaction)
    msp-release.sh run 0.4.0-rc.1

    # Resume (fully automated, no confirmation)
    msp-release.sh resume 0.3.0-rc.9

    # Preflight validation
    msp-release.sh preflight

    # Create/verify GitHub releases for all binary pods (補償命令)
    msp-release.sh create-github-releases 1.0.4-rc.10

CONFIG FILE FORMAT (release.yaml):
    version: "0.0.3"
    base_branch: ""              # Empty = auto-detect current branch
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
    - Scripts/config/release.yaml
    - Docs/RELEASE_SYSTEM_ANALYSIS.md
EOF
}

# ============================================================================
# Version Display
# ============================================================================
# @description Displays the CLI version and feature information
# @return Echoes version info to stdout
msp_show_version() {
    local version="${MSP_RELEASE_VERSION:-unknown}"
    local config_status="not available"
    local default_config="${DEFAULT_CONFIG_FILE:-Scripts/config/release.yaml}"
    local modular_script="${MODULAR_SCRIPT:-Scripts/release/orchestrator/modular.sh}"
    local pods_script="${COCOAPODS_SCRIPT:-Scripts/release/publish/pods/publish.sh}"
    local spm_script="${SPM_SCRIPT:-Scripts/release/publish/spm/publish.sh}"

    if [[ "${CONFIG_MODULE_LOADED:-false}" == "true" ]]; then
        config_status="loaded"
    fi

    echo "msp-release.sh version $version"
    echo ""
    echo "Features:"
    echo "  - Config module: $config_status"
    echo "  - Default config: $default_config"
    echo ""
    echo "Underlying scripts:"
    echo "  modular.sh:   $modular_script"
    echo "  pods/publish.sh: $pods_script"
    echo "  spm/publish.sh:  $spm_script"
}

# Export functions
export -f msp_show_help 2>/dev/null || true
export -f msp_show_version 2>/dev/null || true
