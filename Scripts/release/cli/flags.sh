#!/usr/bin/env bash
# ============================================================================
# MSP Release CLI - Flag Parser Module
# ============================================================================
# Purpose: Parses command-line flags and detects subcommands
# Usage:   source Scripts/release/cli/flags.sh
#          msp_parse_flags "$@"
#          msp_detect_subcommand "${REMAINING_ARGS[@]}"
#
# Dependencies:
#   - log::* functions (from common.sh)
#
# Exports:
#   - VERBOSE, DRY_RUN, NO_ANSI, etc. (flag variables)
#   - SUBCOMMAND, REMAINING_ARGS (subcommand detection)
#   - CLI_VERSION, CLI_RELEASE_NOTES, CLI_BASE_BRANCH (CLI overrides)
# ============================================================================

# Prevent multiple sourcing
[[ -n "${_MSP_CLI_FLAGS_SOURCED:-}" ]] && return 0
readonly _MSP_CLI_FLAGS_SOURCED=1

# ============================================================================
# Subcommand Registry
# ============================================================================
readonly MSP_SUBCOMMANDS=(
    "help"
    "version"
    "config"
    "env"
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
# Flag Parser
# ============================================================================
# @description Parses all flags from arguments, supports flags before and after subcommand
# @param $@ - All command line arguments
# @return Sets global flag variables and REMAINING_ARGS array
# @globals VERBOSE, DRY_RUN, NO_ANSI, SKIP_PREFLIGHT, SKIP_PODS, SKIP_SPM,
#          ONLY_PODS, ONLY_SPM, FORCE, FULL_MODE, CONFIG_FILE,
#          CLI_VERSION, CLI_RELEASE_NOTES, CLI_BASE_BRANCH, SUBCOMMAND, PROFILE, REMAINING_ARGS
# shellcheck disable=SC2034 # Variables are used by caller
msp_parse_flags() {
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

            --no-ansi)
                NO_ANSI=true
                shift
                ;;

            --force)
                FORCE=true
                shift
                ;;

            --full)
                # Phase 5: Enable full release mode (includes verification)
                # Default is simple mode (no verification)
                FULL_MODE=true
                shift
                ;;

            --base-branch)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    CLI_BASE_BRANCH="$2"
                    shift 2
                else
                    log::error "RELEASE" "--base-branch requires a value"
                    exit 1
                fi
                ;;

            --base-branch=*)
                CLI_BASE_BRANCH="${1#*=}"
                shift
                ;;

            --release-notes)
                # Phase 7: Release notes via CLI (FR-016)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    CLI_RELEASE_NOTES="$2"
                    shift 2
                else
                    log::error "RELEASE" "--release-notes requires a value"
                    exit 1
                fi
                ;;

            --release-notes=*)
                CLI_RELEASE_NOTES="${1#*=}"
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
                log::warn "RELEASE" "--tier is deprecated in Phase B, use --profile instead"
                log::warn "RELEASE" "  Example: --profile=production (for production mode)"
                log::warn "RELEASE" "  Example: --profile=local-dev (for dry-run mode)"
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
                    log::error "RELEASE" "--profile requires a value"
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
# @description Detects subcommand from remaining args, handles backward compatibility
# @param $@ - Remaining arguments after flag parsing
# @return Sets SUBCOMMAND and updates REMAINING_ARGS
# @globals SUBCOMMAND, CLI_VERSION, REMAINING_ARGS
# shellcheck disable=SC2034 # Variables are used by caller
msp_detect_subcommand() {
    local args=("$@")

    # If no args, default to help
    if [[ ${#args[@]} -eq 0 ]]; then
        SUBCOMMAND="help"
        return 0
    fi

    local first="${args[0]}"

    # Check if first arg is a known subcommand
    for cmd in "${MSP_SUBCOMMANDS[@]}"; do
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

# Export functions
export -f msp_parse_flags 2>/dev/null || true
export -f msp_detect_subcommand 2>/dev/null || true
