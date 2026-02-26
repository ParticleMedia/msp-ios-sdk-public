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

# Release orchestrator uses its own error handling (retry, resume, graceful degradation)
# so strict mode is intentionally disabled at the top level
set +euo pipefail
# shellcheck source=Scripts/lib/path-helpers.sh
source "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/path-helpers.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Load Unified Logging System (Early - before other operations)
# ============================================================================
if [[ -f "$ROOT_DIR/Scripts/release/utils/logger.sh" ]]; then
    # shellcheck source=Scripts/release/utils/logger.sh
    source "$ROOT_DIR/Scripts/release/utils/logger.sh" 2>/dev/null || true
fi

MODULAR_SCRIPT="$SCRIPT_DIR/release/orchestrator/modular.sh"
COCOAPODS_SCRIPT="$SCRIPT_DIR/release/publish/pods/publish.sh"
SPM_SCRIPT="$SCRIPT_DIR/release/publish/spm/publish.sh"
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/config/release.yaml"
readonly MSP_RELEASE_VERSION="1.2.0-phase2-step3"

# ============================================================================
# Source Release Common Library (loads UI system)
# ============================================================================
# Handle NO_ANSI flag early (before sourcing release-common.sh)
if [[ "${NO_ANSI:-false}" == "true" ]]; then
    export NO_COLOR=1
fi

# Loads colors.sh, ui.sh, logging.sh, and shared utils in one shot
if [[ -f "$ROOT_DIR/Scripts/lib/release-common.sh" ]]; then
    # shellcheck source=Scripts/lib/release-common.sh
    source "$ROOT_DIR/Scripts/lib/release-common.sh"
else
    echo "ERROR: release-common.sh not found" >&2
    exit 1
fi

# ============================================================================
# Source Utility Modules
# ============================================================================
# git/github needed for rollback; state for resume capability
[[ -f "$SCRIPT_DIR/release/utils/git.sh" ]] && source "$SCRIPT_DIR/release/utils/git.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/utils/github.sh" ]] && source "$SCRIPT_DIR/release/utils/github.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/utils/state.sh" ]] && source "$SCRIPT_DIR/release/utils/state.sh" 2>/dev/null || true


# ============================================================================
# Source CLI Modules
# ============================================================================
[[ -f "$SCRIPT_DIR/release/cli/resume.sh" ]] && source "$SCRIPT_DIR/release/cli/resume.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/commands.sh" ]] && source "$SCRIPT_DIR/release/cli/commands.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/help.sh" ]] && source "$SCRIPT_DIR/release/cli/help.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/env.sh" ]] && source "$SCRIPT_DIR/release/cli/env.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/flags.sh" ]] && source "$SCRIPT_DIR/release/cli/flags.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/config_helper.sh" ]] && source "$SCRIPT_DIR/release/cli/config_helper.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/run_helpers.sh" ]] && source "$SCRIPT_DIR/release/cli/run_helpers.sh" 2>/dev/null || true
[[ -f "$SCRIPT_DIR/release/cli/dispatch.sh" ]] && source "$SCRIPT_DIR/release/cli/dispatch.sh" 2>/dev/null || true

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

# Verification is controlled by MSP_RELEASE_MODE (full=verify, simple=skip)
# No separate kill-switch needed — mode determines behavior

# ============================================================================
# Subcommand Registry (defined in cli/flags.sh as MSP_SUBCOMMANDS)
# ============================================================================
if [[ -z "${MSP_SUBCOMMANDS:-}" ]]; then
    readonly SUBCOMMANDS=(
        "help" "version" "config" "env" "preflight" "run"
        "pods" "spm" "verify" "verify-matrix" "rollback" "resume"
        "fix-public-tag" "create-github-releases"
    )
else
    readonly SUBCOMMANDS=("${MSP_SUBCOMMANDS[@]}")
fi

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
FULL_MODE=false
CONFIG_FILE=""
CLI_VERSION=""
CLI_RELEASE_NOTES=""
CLI_BASE_BRANCH=""
SUBCOMMAND=""
PROFILE=""

# ============================================================================
# Thin Wrapper Functions (delegate to CLI modules)
# ============================================================================
parse_flags() {
    if command -v msp_parse_flags &>/dev/null; then
        msp_parse_flags "$@"
    else
        REMAINING_ARGS=("$@")
    fi
}

detect_subcommand() {
    if command -v msp_detect_subcommand &>/dev/null; then
        msp_detect_subcommand "$@"
    else
        local args=("$@")
        if [[ ${#args[@]} -eq 0 ]]; then
            SUBCOMMAND="help"
        else
            SUBCOMMAND="${args[0]}"
            REMAINING_ARGS=("${args[@]:1}")
        fi
    fi
}

show_help() {
    if command -v msp_show_help &>/dev/null; then
        msp_show_help
    else
        echo "Error: help.sh module not loaded" >&2
        exit 1
    fi
}

show_version() {
    if command -v msp_show_version &>/dev/null; then
        msp_show_version
    else
        echo "msp-release.sh version $MSP_RELEASE_VERSION"
    fi
}

# Backward compatibility aliases
load_release_config() { command -v msp_load_release_config &>/dev/null && msp_load_release_config; }
load_and_apply_config() { load_release_config; }
apply_cli_overrides() { command -v msp_apply_cli_overrides &>/dev/null && msp_apply_cli_overrides; }
apply_disable_verification() { command -v msp_apply_disable_verification &>/dev/null && msp_apply_disable_verification; }

# ============================================================================
# Dispatch (delegates to cli/dispatch.sh)
# ============================================================================
dispatch_subcommand() {
    if command -v msp_dispatch_subcommand &>/dev/null; then
        msp_dispatch_subcommand
    else
        log::error "RELEASE" "dispatch.sh module not loaded"
        exit 1
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Capture original CLI arguments for state tracking
    MSP_RELEASE_ORIGINAL_ARGS="$*"
    export MSP_RELEASE_ORIGINAL_ARGS

    # Initialize REMAINING_ARGS
    REMAINING_ARGS=()

    # Parse all flags first (supports flags before subcommand)
    parse_flags "$@"

    # Load configuration from profile
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
        show_help
        exit 0
    fi

    if [[ "$SUBCOMMAND" == "version" ]]; then
        show_version
        exit 0
    fi

    # Dispatch to subcommand handler
    dispatch_subcommand
}

main "$@"
